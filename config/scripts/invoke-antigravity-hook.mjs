#!/usr/bin/env node
// invoke-antigravity-hook.mjs
// Lightweight, cross-platform security router for file tools (PreToolUse) and Gate 2 diff injection (PostToolUse).
// Zero external dependencies.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function getPropValue(obj, names) {
  if (!obj || typeof obj !== 'object') return undefined;
  for (const name of names) {
    if (Object.prototype.hasOwnProperty.call(obj, name) && obj[name] !== undefined) {
      return obj[name];
    }
  }
  const lowerMap = new Map();
  for (const key of Object.keys(obj)) {
    lowerMap.set(key.toLowerCase(), obj[key]);
  }
  for (const name of names) {
    const val = lowerMap.get(name.toLowerCase());
    if (val !== undefined) return val;
  }
  return undefined;
}

function writeHookLog(message) {
  try {
    const userHome = process.env.USERPROFILE || process.env.HOME || '';
    if (!userHome) return;
    const scratchDir = path.join(userHome, '.gemini', 'antigravity', 'scratch');
    if (!fs.existsSync(scratchDir)) {
      fs.mkdirSync(scratchDir, { recursive: true });
    }
    const logFile = path.join(scratchDir, 'hooks.log');
    const maxBytes = 5 * 1024 * 1024;
    if (fs.existsSync(logFile)) {
      const stat = fs.statSync(logFile);
      if (stat.size >= maxBytes) {
        const keepBytes = 1024 * 1024;
        const fd = fs.openSync(logFile, 'r');
        const buf = Buffer.alloc(keepBytes);
        fs.readSync(fd, buf, 0, keepBytes, stat.size - keepBytes);
        fs.closeSync(fd);
        fs.writeFileSync(logFile, buf);
      }
    }
    const ts = new Date().toISOString();
    fs.appendFileSync(logFile, `[${ts}] ${message}\n`, 'utf8');
  } catch {
    // Logging failure must never fail the hook
  }
}

function writeHookResponse(responseObj) {
  process.stdout.write(JSON.stringify(responseObj));
}

async function readStdin() {
  if (process.stdin.isTTY) return '';
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

function getNormalizedPath(rawPath) {
  if (!rawPath || typeof rawPath !== 'string') return '';
  let p = rawPath.trim().replace(/^["']|["']$/g, '');
  const userHome = process.env.USERPROFILE || process.env.HOME || '';
  const userHomeNorm = userHome.replace(/\\/g, '/').replace(/\/+$/, '');

  if (userHomeNorm && /^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)(?=[/\\]|$)/.test(p)) {
    p = p.replace(/^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)/, userHomeNorm);
  }
  p = p.replace(/\\/g, '/');

  if (/^file:\/\/\/([A-Za-z]:.*)$/.test(p)) {
    p = p.replace(/^file:\/\/\//, '');
  } else if (/^file:\/\/(\/.*)$/.test(p)) {
    p = p.replace(/^file:\/\//, '');
  }
  if (/^\/\/[.?]\/([A-Za-z]:.*)$/.test(p)) {
    p = p.replace(/^\/\/[.?]\//, '');
  }

  let prefix = '';
  let rest = p;
  const driveMatch = p.match(/^([A-Za-z]:)(.*)$/);
  if (driveMatch) {
    prefix = driveMatch[1].toLowerCase() + '/';
    rest = driveMatch[2].replace(/^\/+/, '');
  } else if (p.startsWith('//')) {
    prefix = '//';
    rest = p.replace(/^\/+/, '');
  } else if (p.startsWith('/')) {
    prefix = '/';
    rest = p.replace(/^\/+/, '');
  }

  const stack = [];
  for (const seg of rest.split('/')) {
    if (!seg || seg === '.') continue;
    if (seg === '..') {
      if (stack.length > 0 && stack[stack.length - 1] !== '..') {
        stack.pop();
      } else if (!prefix) {
        stack.push('..');
      }
      continue;
    }
    const cleanSeg = seg.toLowerCase().replace(/[\. ]+$/, '');
    if (!cleanSeg) continue;
    stack.push(cleanSeg);
  }

  return prefix + stack.join('/');
}

function testLexicalDenyPath(normPath) {
  if (!normPath || typeof normPath !== 'string') return false;

  const parts = normPath.split('/');
  const rawLeaf = parts[parts.length - 1] || '';
  const leaf = rawLeaf.replace(/:.*$/, '').replace(/[\. ]+$/, '');
  parts[parts.length - 1] = leaf;
  const normNoAds = parts.join('/');

  if (/^\.env/.test(leaf) && !['.env.example', '.env.sample', '.env.template'].includes(leaf)) {
    return true;
  }
  if (/\.(key|pem)$/.test(leaf)) {
    return true;
  }
  if (/(^|\/)(\.ssh|\.aws|\.gnupg)(\/|$)/.test(normNoAds)) {
    return true;
  }
  if (/(^|\/)\.gemini\/(?:antigravity[^/]*\/)?mcp(\/|$)/.test(normNoAds)) {
    return true;
  }
  if (/(^|\/)\.gemini\/(?:config\/|antigravity[^/]*\/)?mcp_config[^/]*\.json$/.test(normNoAds)) {
    return true;
  }
  if (/(^|\/)\.gemini\/(?:antigravity[^/]*\/)?mcp_oauth_tokens[^/]*\.json$/.test(normNoAds)) {
    return true;
  }
  if (/(^|\/)\.agents\/mcp_config[^/]*\.json$/.test(normNoAds)) {
    return true;
  }

  return false;
}

function testDenyPath(rawPath, depth = 0) {
  if (depth > 8) {
    return { denied: true, reason: 'Symlink recursion depth limit exceeded (> 8).' };
  }

  const norm = getNormalizedPath(rawPath);
  if (!norm) return { denied: false };
  if (testLexicalDenyPath(norm)) return { denied: true };

  let expanded = String(rawPath).trim().replace(/^["']|["']$/g, '');
  const userHome = process.env.USERPROFILE || process.env.HOME || '';
  if (userHome && /^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)(?=[/\\]|$)/.test(expanded)) {
    expanded = expanded.replace(/^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)/, userHome.replace(/[\\/]+$/, ''));
  }
  if (/^file:\/\/\/([A-Za-z]:.*)$/.test(expanded)) {
    expanded = expanded.replace(/^file:\/\/\//, '');
  } else if (/^file:\/\/(\/.*)$/.test(expanded)) {
    expanded = expanded.replace(/^file:\/\//, '');
  }

  if (process.platform === 'win32') {
    expanded = expanded.replace(/\//g, '\\');
    if (/^\\\\[.?]\\([A-Za-z]:.*)$/.test(expanded)) {
      expanded = expanded.replace(/^\\\\[.?]\\/, '');
    }
    let drivePart = '';
    let bodyPart = expanded;
    const dm = expanded.match(/^([A-Za-z]:)(.*)$/);
    if (dm) {
      drivePart = dm[1];
      bodyPart = dm[2];
    }
    const lastSlash = bodyPart.lastIndexOf('\\');
    if (lastSlash >= 0) {
      const segs = bodyPart.substring(0, lastSlash + 1);
      const leafPart = bodyPart.substring(lastSlash + 1).replace(/:.*$/, '');
      expanded = drivePart + segs + leafPart;
    } else {
      expanded = drivePart + bodyPart.replace(/:.*$/, '');
    }
  } else {
    expanded = expanded.replace(/\\/g, '/');
    if (/^[A-Za-z]:/.test(expanded)) {
      // Cross-platform compatibility per 5bee5a6: drive letter does not exist on POSIX
      return { denied: false };
    }
  }

  let fullProbe;
  try {
    fullProbe = path.resolve(expanded);
    const fullNorm = getNormalizedPath(fullProbe);
    if (testLexicalDenyPath(fullNorm)) return { denied: true };
  } catch (err) {
    return { ask: true, reason: err.message };
  }

  let probe = fullProbe.replace(/[\\/]+$/, '');
  if (process.platform === 'win32' && /^[A-Za-z]:$/.test(probe)) {
    probe += '\\';
  } else if (process.platform !== 'win32' && !probe) {
    probe = '/';
  }

  const suffixParts = [];
  while (probe && probe.trim().length > 0) {
    let stat;
    try {
      stat = fs.lstatSync(probe, { throwIfNoEntry: false });
    } catch (err) {
      return { ask: true, reason: err.message };
    }

    let isReparsePoint = Boolean(stat && stat.isSymbolicLink());
    let rawTarget = null;

    if (isReparsePoint) {
      try {
        rawTarget = fs.readlinkSync(probe);
      } catch (err) {
        if (err.code === 'ELOOP') return { denied: true, reason: 'Symlink loop detected.' };
        return { ask: true, reason: err.message };
      }
    } else if (process.platform === 'win32' && stat && stat.isDirectory()) {
      try {
        rawTarget = fs.readlinkSync(probe);
        isReparsePoint = Boolean(rawTarget);
      } catch (err) {
        if (err.code === 'ELOOP') {
          return { denied: true, reason: 'Symlink loop detected.' };
        }
        if (err.code === 'EINVAL' || err.code === 'ENOENT' || err.code === 'UNKNOWN') {
          isReparsePoint = false;
        } else {
          return { ask: true, reason: err.message };
        }
      }
    }

    if (isReparsePoint && rawTarget) {
      let resolvedTarget = rawTarget;
      if (!path.isAbsolute(resolvedTarget)) {
        const probeParent = path.dirname(probe);
        resolvedTarget = path.resolve(probeParent, resolvedTarget);
      }
      let candidate = resolvedTarget;
      if (suffixParts.length > 0) {
        candidate = path.join(candidate, ...suffixParts);
      }
      const subResult = testDenyPath(candidate, depth + 1);
      if (subResult.denied) return subResult;
      if (subResult.ask) return subResult;
    }

    const parent = path.dirname(probe);
    if (!parent || parent === probe) break;
    const leafName = path.basename(probe);
    if (leafName) {
      suffixParts.unshift(leafName);
    }
    probe = parent;
  }

  return { denied: false };
}

function hasError(rawError) {
  if (rawError === null || rawError === undefined || rawError === false) return false;
  if (typeof rawError === 'string') return rawError.trim().length > 0;
  if (typeof rawError === 'object') {
    if (Array.isArray(rawError)) return rawError.length > 0;
    return Object.keys(rawError).length > 0;
  }
  return Boolean(rawError);
}

// ==============================================================================
// MAIN EXECUTION ROUTER
// ==============================================================================

let eventName = 'PreToolUse';
const cliArgs = process.argv.slice(2);
for (let i = 0; i < cliArgs.length; i++) {
  const arg = cliArgs[i];
  if (arg === '-Event' || arg === '--event' || arg === '-e') {
    eventName = cliArgs[i + 1] || eventName;
    i++;
  } else if (!arg.startsWith('-')) {
    eventName = arg;
  }
}

try {
  let rawInput = '';
  try {
    rawInput = await readStdin();
  } catch (err) {
    throw new Error(`Failed to read stdin: ${err.message}`);
  }

  if (rawInput) {
    if (rawInput.charCodeAt(0) === 0xFEFF) {
      rawInput = rawInput.slice(1);
    }
    rawInput = rawInput.trim();
  }

  if (!rawInput) {
    throw new Error('Empty hook payload on stdin.');
  }

  let payload;
  try {
    payload = JSON.parse(rawInput);
  } catch (parseErr) {
    throw new Error(`Invalid JSON in hook payload: ${parseErr.message}`);
  }

  const toolCall = getPropValue(payload, ['toolCall']);
  if (!toolCall) {
    throw new Error('Missing toolCall object in hook payload.');
  }

  const toolName = String(getPropValue(toolCall, ['name']) || '');
  const toolArgs = getPropValue(toolCall, ['args']) || {};
  const pathPropKeys = [
    'AbsolutePath',
    'TargetFile',
    'Path',
    'FilePath',
    'file_path',
    'target_file',
    'absolute_path',
    'path',
    'SearchPath',
    'search_path',
  ];

  if (eventName === 'PostToolUse') {
    const rawError = getPropValue(payload, ['error']);
    const postDiffTools = [
      'write_to_file',
      'write_file',
      'create_file',
      'replace_file_content',
      'multi_replace_file_content',
      'edit_file',
      'apply_diff',
    ];

    if (!hasError(rawError) && postDiffTools.includes(toolName)) {
      const rawTargetFile = getPropValue(toolArgs, pathPropKeys);
      const targetFile = rawTargetFile ? String(rawTargetFile).trim() : '';
      if (targetFile && path.basename(targetFile).toLowerCase() === 'gate2_handoff.md') {
        if (fs.existsSync(targetFile)) {
          let fileText = fs.readFileSync(targetFile, 'utf8');
          if (fileText.includes('{{VERBATIM_GIT_DIFF}}') || fileText.includes('{{VERBATIM_GIT_DIFFSTAT}}')) {
            try {
              const updateScript = path.join(__dirname, 'Update-Gate2Diff.ps1');
              if (!fs.existsSync(updateScript)) {
                throw new Error(`Update-Gate2Diff.ps1 not found at ${updateScript}`);
              }
              let repoArg = null;
              const wsPaths = getPropValue(payload, ['workspacePaths']);
              if (Array.isArray(wsPaths)) {
                for (const ws of wsPaths) {
                  const wsStr = String(ws || '').trim();
                  if (wsStr && fs.existsSync(wsStr)) {
                    try {
                      const isDir = fs.statSync(wsStr).isDirectory();
                      if (isDir) {
                        const gitCheck = spawnSync('git', ['-C', wsStr, 'rev-parse', '--is-inside-work-tree'], {
                          encoding: 'utf8',
                          stdio: ['ignore', 'pipe', 'ignore'],
                        });
                        if (gitCheck.status === 0 && (gitCheck.stdout || '').trim() === 'true') {
                          repoArg = wsStr;
                          break;
                        }
                        if (!repoArg) repoArg = wsStr;
                      }
                    } catch {}
                  }
                }
              }

              const psExe = process.env.POWERSHELL_BIN || (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
              const psArgs = [
                '-NoProfile',
                '-NonInteractive',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                updateScript,
                '-ArtifactPath',
                targetFile,
              ];
              if (repoArg) {
                psArgs.push('-RepoPath', repoArg);
              }

              const proc = spawnSync(psExe, psArgs, {
                stdio: ['ignore', 'ignore', 'pipe'],
                encoding: 'utf8',
              });
              if (proc.status !== 0) {
                const stderrMsg = proc.stderr ? proc.stderr.trim() : '';
                throw new Error(stderrMsg || `Update-Gate2Diff.ps1 exited with code ${proc.status}`);
              }
            } catch (g4Err) {
              const errMsg = g4Err.message || String(g4Err);
              writeHookLog(`Event=PostToolUse Guard4 Update-Gate2Diff failed: ${errMsg}`);
              const banner = `[ERROR: Update-Gate2Diff.ps1 failed \u2014 ${errMsg}]`;
              const updatedText = fileText
                .replaceAll('{{VERBATIM_GIT_DIFFSTAT}}', banner)
                .replaceAll('{{VERBATIM_GIT_DIFF}}', banner);
              fs.writeFileSync(targetFile, updatedText, 'utf8');
            }
          }
        }
      }
    }

    writeHookResponse({});
    process.exit(0);
  }

  // PreToolUse Routing
  const handledFileTools = [
    'view_file',
    'read_file',
    'replace_file_content',
    'multi_replace_file_content',
    'edit_file',
    'write_to_file',
    'write_file',
    'create_file',
    'apply_diff',
    'grep_search',
  ];

  if (handledFileTools.includes(toolName)) {
    let rawPath = getPropValue(toolArgs, pathPropKeys);
    if (!rawPath || (typeof rawPath === 'string' && rawPath.trim().length === 0)) {
      if (toolName === 'grep_search') {
        rawPath = '.';
      } else {
        writeHookResponse({
          decision: 'ask',
          reason: `Missing target file path argument in ${toolName} payload.`,
        });
        process.exit(0);
      }
    }

    const checkResult = testDenyPath(String(rawPath));
    if (checkResult.denied) {
      writeHookResponse({
        decision: 'deny',
        reason: `Blocked by Security Hook: Access to credential or secret path '${rawPath}' is prohibited.`,
      });
      process.exit(0);
    }
    if (checkResult.ask) {
      writeHookResponse({
        decision: 'ask',
        reason: `Hook fallback (PreToolUse): ${checkResult.reason}`,
      });
      process.exit(0);
    }

    writeHookResponse({ decision: 'allow' });
    process.exit(0);
  }

  // Default passthrough for non-file tools
  writeHookResponse({ decision: 'allow' });
  process.exit(0);
} catch (err) {
  const errMsg = err.message || String(err);
  writeHookLog(`Event=${eventName} Error=${errMsg}`);
  if (eventName === 'PostToolUse') {
    writeHookResponse({});
  } else {
    writeHookResponse({
      decision: 'ask',
      reason: `Hook fallback (${eventName}): ${errMsg}`,
    });
  }
  process.exit(0);
}
