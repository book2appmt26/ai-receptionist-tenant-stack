# ai-receptionist-tenant-stack

Terraform module suite that provisions a **single tenant's data
plane** in the client's own Azure subscription, per the
hub-and-spoke (Model C) deployment model.

This repo is consumed by [`tenant-configs`](https://github.com/book2appmt26/tenant-configs)
(private), which holds one `<tenant_id>.tfvars` file per client. The
CI workflows in `.github/workflows/` plan + apply against those
tfvars on PR-driven flow.

## What gets provisioned per tenant

Composed by `envs/tenant.tf` (task 2.11) from the modules under `modules/`:

| Module | What it creates | EPIC-2 task |
|---|---|---|
| `tenant-network` | VNet + subnets + private DNS zones | 2.3 |
| `tenant-postgres` | PG Flex HA, CMK from tenant KV, private endpoint, pgvector extension | 2.4 |
| `tenant-redis` | Premium Redis, private endpoint, no public access | 2.5 |
| `tenant-keyvault` | RBAC mode, soft-delete + purge protection on | 2.6 |
| `tenant-storage` | Storage account (recording-disabled by default; lifecycle template ready) | 2.7 |
| `tenant-entra` | App registration in client Entra + federated credential bound to our AKS SA | 2.8 |
| `tenant-vnet-peering` | Peer client VNet ↔ our compute VNet, both directions | 2.9 |
| `tenant-rbac` | SA → resources within tenant, least-privilege | 2.10 |

## Layout

```
modules/
├── tenant-network/
├── tenant-postgres/
├── tenant-redis/
├── tenant-keyvault/
├── tenant-storage/
├── tenant-entra/
├── tenant-vnet-peering/
└── tenant-rbac/
envs/
└── tenant.tf            # composer; consumes a tfvars from tenant-configs
migrations/              # baseline schema (auth.tenants, app.calls, app.transcripts, …) — task 2.13
scripts/
└── onboard-client.sh    # prints the az role assignments the client admin must run — task 2.17
.github/workflows/
├── tenant-plan.yml      # PR-driven plan against tenant-configs tfvars — task 2.14
├── tenant-apply.yml     # manual approve, two reviewers — task 2.15
└── tenant-destroy.yml   # protected, two reviewers, typed tenant_id confirmation — task 2.16
```

## Required inputs (from a tenant tfvars)

Per task 2.11, the composer requires:

- `tenant_id` (string, slug-form: lowercase a-z, 0-9, `-`)
- `region` (string; v1 supports East US 2 only — negative test 2.10)
- `client_subscription_id` (UUID — the **client's** Azure subscription)
- `client_entra_tenant_id` (UUID — the client's Entra tenant)

## Conventions

- Terraform: `hashicorp/azurerm` and `hashicorp/azuread`. State backend
  is `azurerm` against our `airxtfstate` Storage account; **one
  container per tenant** (`tenant-<tenant_id>`).
- All resources tagged with at least `CostCenter`, `Tenant=<tenant_id>`.
- No public network access on any resource. Workload-Identity
  Federation only — no long-lived secrets.
- Forward-only schema migrations (Constitution Article III).

## Related repos

- [`ai-receptionist-platform`](https://github.com/book2appmt26/ai-receptionist-platform)
  — shared platform infrastructure + Helm charts + EPIC documentation.
- [`ai-receptionist-orchestrator`](https://github.com/book2appmt26/ai-receptionist-orchestrator)
  — the voice pipeline image deployed by the platform repo's
  `helm/orchestrator/` chart into the AKS cluster that connects to
  the tenants this repo provisions.
- `tenant-configs` (private) — per-tenant tfvars consumed by this
  repo's CI workflows.

## Status

🟧 **Initial scaffold.** All eight `modules/*` directories are
placeholders with stub `main.tf`/`variables.tf`/`outputs.tf` files
that document intent but produce no resources. Implementation
proceeds task-by-task per
[`ai-receptionist-platform/documentation/04-Tasks.md`](https://github.com/book2appmt26/ai-receptionist-platform/blob/main/documentation/04-Tasks.md) §EPIC-2.
