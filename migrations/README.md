# Tenant baseline schema migrations

EPIC-2 task 2.13. Authored as either `sqitch` or `flyway` migrations
(decision pending). Targets the per-tenant Postgres provisioned by
`modules/tenant-postgres/` and run by the migration Job in task 2.12.

Schemas to land here per the architecture doc:

- `auth.tenants`
- `app.calls`
- `app.transcripts`
- `app.tool_invocations`
- `app.review_queue`
- `app.audit_events` (partitioned)
- `app.knowledge_chunks` (pgvector)

Forward-only per Constitution Article III. Down-migrations are not
authored or applied in production.
