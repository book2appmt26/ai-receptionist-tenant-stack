# tenant-postgres — PG Flex HA, CMK from tenant KV, private endpoint,
# pgvector extension allowlisted. EPIC-2 task 2.4.
#
# Adapted from ai-receptionist-platform/modules/control-plane-pg/.
# Substantive differences for the tenant context:
#  - HA enabled by default (control-plane PG was Burstable B2ms,
#    HA-incompatible; tenant PG must be GeneralPurpose+).
#  - User-assigned identity for CMK access lives inside the module,
#    not as an input — it's tenant-scoped and has no other consumers.
#  - The deployer (current Terraform identity) is registered as the
#    AAD admin so the migration job (task 2.12) can connect over
#    AAD to apply schemas. Per-MI data-plane principals
#    (orchestrator, etc.) get enrolled later as regular roles via
#    `pgaadauth_create_principal()` from inside the cluster, same
#    pattern as the control-plane PG.
#  - `azure.extensions = "VECTOR"` allowlists pgvector — the actual
#    `CREATE EXTENSION vector` runs from the migration job because
#    the deployer SP doesn't have CREATE EXTENSION in v1.
#  - No diagnostic_setting yet — tenant-side LAW integration is
#    EPIC-7 hardening territory.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  server_name = "psql-airx-${var.tenant_id}"

  tags = {
    CostCenter = "ai-receptionist"
    Tenant     = var.tenant_id
    ManagedBy  = "terraform"
  }
}

# ── User-assigned identity for CMK access ───────────────────────────
# PG Flex needs a UA identity with `Key Vault Crypto Service
# Encryption User` on the CMK key vault. Pre-grant the role and wait
# for AAD propagation before the server resource depends on it.

resource "azurerm_user_assigned_identity" "cmk" {
  name                = "id-cmk-${var.tenant_id}"
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = local.tags
}

resource "azurerm_role_assignment" "cmk_consumer" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.cmk.principal_id
}

resource "time_sleep" "wait_for_cmk_rbac" {
  depends_on      = [azurerm_role_assignment.cmk_consumer]
  create_duration = "60s"
}

# ── PG Flex Server ──────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "tenant" {
  name                          = local.server_name
  location                      = var.region
  resource_group_name           = var.resource_group_name
  version                       = var.pg_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  # administrator_login intentionally omitted: azurerm 4.x rejects it
  # at create-time when password_auth_enabled = false (which is
  # required by Constitution Article IV.3 — no long-lived secrets).

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.standby_availability_zone
    }
  }

  customer_managed_key {
    key_vault_key_id                  = var.cmk_key_versionless_id
    primary_user_assigned_identity_id = azurerm_user_assigned_identity.cmk.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cmk.id]
  }

  tags = local.tags

  depends_on = [time_sleep.wait_for_cmk_rbac]

  # Azure auto-assigns zone on first create. Without ignore_changes,
  # terraform plans to null on subsequent applies, which Azure rejects.
  lifecycle {
    ignore_changes = [zone]
  }
}

# Register the deployer (current Terraform identity) as the AAD admin
# so the task-2.12 migration job can connect over AAD and apply the
# baseline schema. Data-plane principals get enrolled separately via
# `pgaadauth_create_principal()` from inside the cluster (see
# ai-receptionist-platform/scripts/enroll-pg-aad-principal.ps1 for
# the pattern; tenant-rbac task 2.10 will do the same).
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "deployer" {
  server_name         = azurerm_postgresql_flexible_server.tenant.name
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  principal_name      = "deployer-${var.tenant_id}"
  principal_type      = "ServicePrincipal"
}

# ── Private endpoint ────────────────────────────────────────────────

resource "azurerm_private_endpoint" "pg" {
  name                = "pe-${local.server_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-pg"
    private_connection_resource_id = azurerm_postgresql_flexible_server.tenant.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dzg-pg"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# ── Post-create settle + server config ──────────────────────────────
# PG performs HA wiring + CMK setup + replica sync for ~1-2 min after
# the endpoint reports ready. Configuration writes during this window
# return ServerIsBusy. Wait it out before the first config update.

resource "time_sleep" "pg_settle" {
  depends_on      = [azurerm_postgresql_flexible_server.tenant]
  create_duration = "120s"
}

# Allowlist pgvector. The actual `CREATE EXTENSION vector` happens in
# the task-2.12 migration job — the deployer SP doesn't have CREATE
# EXTENSION in v1 (PG Flex grants are tightly scoped).
resource "azurerm_postgresql_flexible_server_configuration" "azure_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.tenant.id
  value     = "VECTOR"

  depends_on = [time_sleep.pg_settle]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.tenant.id
  value     = "on"

  depends_on = [time_sleep.pg_settle]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.tenant.id
  value     = "on"

  depends_on = [time_sleep.pg_settle]
}
