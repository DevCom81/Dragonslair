# Migration scripts (LOT 12 / LOT 14B)

These tools never talk to Flutter, WorkOS dashboards, Stripe, or Play Console.
They read a local export and, only when explicitly armed, call `npx convex run`
against the deployment named by `CONVEX_DEPLOYMENT`.

## Staging / dev

Current Convex CLI selector example: `dev:dusty-rabbit-684`.

1. `npm run migrate:export`
2. `npm run migrate:dry-run`
3. `npm run migrate:workos-map`
4. `npm run migrate:workos-create` (only if mappings are missing)
5. Import dry-run (no writes):

```bash
npx tsx scripts/migration/cli.ts convex-import \
  --dir migration-export \
  --mapping-dir migration-work \
  --dry-run
```

6. Import execute:

```bash
CONVEX_DEPLOYMENT=dev:PLACEHOLDER_DEV \
CONVEX_MIGRATION_CONFIRM=dev:PLACEHOLDER_DEV \
npx tsx scripts/migration/cli.ts convex-import \
  --dir migration-export \
  --mapping-dir migration-work \
  --execute \
  --target dev:PLACEHOLDER_DEV
```

7. Audit (read-only, `--target` required):

```bash
CONVEX_DEPLOYMENT=dev:PLACEHOLDER_DEV \
npx tsx scripts/migration/cli.ts convex-audit \
  --dir migration-export \
  --mapping-dir migration-work \
  --target dev:PLACEHOLDER_DEV
```

## Production

A production selector is:

- Convex CLI `prod:<deployment>` (kind prefix), or
- any selector matching `/prod/i` (LOT 12 conservative guard), or
- the exact value of optional `CONVEX_PRODUCTION_DEPLOYMENT` once the real prod selector is known (do not invent a name).

`--execute` plus `CONVEX_DEPLOYMENT=prod:...` is **not** enough.

Production **writes** require all of:

1. `--execute`
2. `--target` exactly equal to `CONVEX_DEPLOYMENT`
3. `CONVEX_MIGRATION_CONFIRM` exactly equal to `CONVEX_DEPLOYMENT`
4. `CONVEX_PRODUCTION_CONFIRM=DRAGONSLAIR_PRODUCTION`

`DRAGONSLAIR_PRODUCTION` is a non-secret arming phrase. It is not an API key.
It must be absent by default.

Example (placeholder deployment only):

```bash
CONVEX_DEPLOYMENT=prod:PLACEHOLDER_DEPLOYMENT \
CONVEX_MIGRATION_CONFIRM=prod:PLACEHOLDER_DEPLOYMENT \
CONVEX_PRODUCTION_CONFIRM=DRAGONSLAIR_PRODUCTION \
npx tsx scripts/migration/cli.ts convex-import \
  --dir migration-export \
  --mapping-dir migration-work \
  --execute \
  --target prod:PLACEHOLDER_DEPLOYMENT
```

Order of protections (fail closed):

1. Plan must be `CONVEX_IMPORT_READY`
2. `--execute` and `--dry-run` are mutually exclusive
3. `--target` and `CONVEX_DEPLOYMENT` required and identical
4. `CONVEX_MIGRATION_CONFIRM` equals `CONVEX_DEPLOYMENT`
5. If the selector is production: `CONVEX_PRODUCTION_CONFIRM` must equal `DRAGONSLAIR_PRODUCTION`

Mismatch, missing confirm, or wrong confirm: no writer, no Convex mutation.

## Dry-run

`convex-import` without `--execute`, or with `--dry-run`, never writes.
Production arming is not required.

The dataset dry-run (`npm run migrate:dry-run`) is unchanged and never talks to Convex.

## convex-audit

`internal.migrationAudit.snapshot` is an internal **query**. Audit is read-only.
`--execute` / `--import` are refused.

`--target` and matching `CONVEX_DEPLOYMENT` are required.
Production write confirm is **not** required.

```bash
CONVEX_DEPLOYMENT=prod:PLACEHOLDER_DEPLOYMENT \
npx tsx scripts/migration/cli.ts convex-audit \
  --dir migration-export \
  --mapping-dir migration-work \
  --target prod:PLACEHOLDER_DEPLOYMENT
```

## Identity

Import upserts by `legacyUuid` and WorkOS subject. Convex `_id` values from
staging (`dusty-rabbit-684`) are not an import authority.
