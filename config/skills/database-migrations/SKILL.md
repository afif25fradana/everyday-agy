---
name: database-migrations
description: "Safe, reversible database migration patterns: forward-only production changes, expand-contract zero-downtime renames, concurrent indexes, batched backfills, and tooling workflows (PostgreSQL, Prisma, Drizzle, Kysely, Alembic). Use when writing a schema or data migration, adding columns or indexes to large tables, planning rollbacks, or preparing zero-downtime deploys."
---

# Database Migration Patterns

Safe, reversible database schema changes for production systems. Governed by zero-downtime discipline and non-blocking DDL execution.

## When to Activate

- Creating or altering database tables
- Adding/removing columns or indexes
- Running data migrations (backfill, transformation)
- Planning zero-downtime schema changes
- Setting up migration tooling for a new project

## Core Principles

1. **Every change is a migration** — never alter production databases manually.
2. **Migrations are forward-only in production** — rollbacks use new forward migrations.
3. **Schema and data migrations are separate** — never mix DDL (schema) and DML (data) in one migration.
4. **Test migrations against production-sized data** — a migration that works on 100 rows may lock on 10M.
5. **Migrations are immutable once deployed** — never edit a migration that has already executed in production.

## Migration Safety Checklist

Before applying any migration:

- [ ] Migration has both UP and DOWN (or is explicitly documented as irreversible).
- [ ] No full table locks on large tables (use non-blocking concurrent operations).
- [ ] New columns have defaults or are nullable (never add `NOT NULL` without default on existing tables).
- [ ] Indexes created concurrently (`CREATE INDEX CONCURRENTLY`).
- [ ] Data backfill is a separate migration from schema change.
- [ ] Foreign keys on large tables indexed to avoid table-scan locks during cascade/checks.
- [ ] Rollback plan documented.

## PostgreSQL Zero-Downtime Patterns

### 1. Adding a Column Safely

```sql
-- GOOD: Nullable column, instant metadata change, no lock
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- GOOD: Column with default (PostgreSQL 11+ is instant, no table rewrite)
ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- BAD: NOT NULL without default on existing table (locks table and rewrites every row)
ALTER TABLE users ADD COLUMN role TEXT NOT NULL;
```

### 2. Adding an Index Without Downtime

```sql
-- BAD: Takes SHARE lock, blocks concurrent writes on large tables
CREATE INDEX idx_users_email ON users (email);

-- GOOD: Non-blocking, allows concurrent reads and writes
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);
-- Note: CONCURRENTLY cannot run inside a multi-statement transaction block.
```

### 3. Renaming a Column (Expand-Contract Pattern)

Never rename a column directly in production (`ALTER TABLE users RENAME COLUMN ...`). Use Expand-Contract:

1. **Phase 1 (Expand)**: Add the new column as nullable.
   ```sql
   ALTER TABLE users ADD COLUMN display_name TEXT;
   ```
2. **Phase 2 (Backfill)**: Backfill data from old column to new column in batches (separate data migration).
3. **Phase 3 (Dual-Write)**: Application code writes to both `username` and `display_name`, reads from `display_name` with fallback to `username`. Deploy code.
4. **Phase 4 (Contract)**: Stop writing to old column. Ensure application reads only `display_name`.
5. **Phase 5 (Prune)**: Drop old column in a subsequent migration.
   ```sql
   ALTER TABLE users DROP COLUMN username;
   ```

### 4. Batched Data Migrations (Prevent Table Locks)

```sql
-- GOOD: Batch update with progress to avoid long-lived transaction locks
DO $$
DECLARE
  batch_size INT := 5000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users
    SET normalized_email = LOWER(email)
    WHERE id IN (
      SELECT id FROM users
      WHERE normalized_email IS NULL
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    COMMIT;
  END LOOP;
END $$;
```

## Tooling Workflows

### Prisma
```bash
# Generate dev migration
rtk npx prisma migrate dev --name add_user_avatar

# Custom SQL for concurrent indexes or backfills:
rtk npx prisma migrate dev --create-only --name add_email_index
# Edit generated SQL file to add CREATE INDEX CONCURRENTLY, then deploy:
rtk npx prisma migrate deploy
```

### Drizzle
```bash
# Generate migration from schema diff
rtk npx drizzle-kit generate

# Run migrations
rtk npx drizzle-kit migrate
```

### Kysely
```typescript
// migrations/2026_10_23_001_create_user.ts
import { type Kysely, sql } from 'kysely';

// Always use Kysely<any> to prevent migrations from breaking when domain models evolve.
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('users')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('email', 'varchar(255)', (col) => col.notNull().unique())
    .addColumn('created_at', 'timestamp', (col) => col.defaultTo(sql`now()`).notNull())
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('users').execute();
}
```

## Related Agents & Skills

- [`database-reviewer`](../../agents/database-reviewer/agent.md) - Specializes in foreign keys, index optimization, and zero-downtime migrations.
- [`audit-dev-workflow`](../audit-dev-workflow/SKILL.md) - Pre-investigation, checkpoints, and Gate 1 proposals.
