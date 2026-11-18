# Contract-First Reference Templates

On-demand OpenAPI and TypeScript boundary examples referenced by [`SKILL.md`](../SKILL.md).

## 1. OpenAPI 3.1.0 Schema (`OrderSummary`)

```yaml
# openapi.yaml
openapi: 3.1.0
components:
  schemas:
    OrderSummary:
      type: object
      required: [id, status, total]
      properties:
        id:
          type: string
          description: Opaque identifier; never parse as a number.
        status:
          type: string
          enum: [pending, paid, cancelled]
        total:
          type: number
          format: double
          minimum: 0
        cancellationReason:
          type: [string, "null"]
```

Define semantic constraints alongside syntax (for example, `cancellationReason` is `null` for every status except `cancelled`).

## 2. TypeScript Consumer Mock

Derived from generated contract types so consumers can build against contract-valid fixtures while the provider is in progress:

```typescript
import type { components } from "./generated/api";

type OrderSummary = components["schemas"]["OrderSummary"];

export const paidOrderMock = {
  id: "9007199254740993123",
  status: "paid",
  total: 49.9,
  cancellationReason: null,
} satisfies OrderSummary;
```

## 3. TypeScript Provider Mapper

Maps internal storage rows to the canonical contract shape at the serialization boundary:

```typescript
import type { components } from "./generated/api";

type OrderSummary = components["schemas"]["OrderSummary"];

export function toOrderSummary(row: OrderRow): OrderSummary {
  return {
    id: String(row.id),
    status: row.status,
    total: row.total,
    cancellationReason: row.cancellation_reason,
  };
}
```
