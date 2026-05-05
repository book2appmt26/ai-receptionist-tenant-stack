# tenant-keyvault — Premium Key Vault, RBAC mode, soft-delete + purge
# protection on, fully private. Hosts the CMK key consumed by
# tenant-postgres (CMK is a Premium-only feature; KV name is
# globally unique so we postfix a deterministic hash of tenant_id).
#
# EPIC-2 task 2.6.
#
# Parallels the platform repo's modules/control-plane-keyvault/. Two
# main differences for the tenant context:
#  - KV name is `kv-${slug}-${hash6}` (≤24 chars, KV name limit).
#  - cmk_consumers role-grants live in tenant-rbac (task 2.10) rather
#    than here, so this module stays focused on the vault + key.

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
  tags = {
    CostCenter = "ai-receptionist"
    Tenant     = var.tenant_id
    ManagedBy  = "terraform"
  }

  # KV name: 3–24 chars, alphanumeric + hyphens, must start with a
  # letter and end with a letter/digit. Build deterministically from
  # the tenant slug so re-applies don't drift, and append a 6-char
  # SHA-256 prefix of tenant_id to keep the global uniqueness story
  # tight without needing the `random` provider. Soft-delete +
  # purge-protection means the name is reserved for 90 days after
  # destroy — the hash gives a stable handle across that window.
  kv_slug = substr(replace(var.tenant_id, "-", ""), 0, 14)
  kv_hash = substr(sha256(var.tenant_id), 0, 6)
  kv_name = lower("kv-${local.kv_slug}-${local.kv_hash}")
}

# ── Vault ────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "tenant" {
  name                          = local.kv_name
  location                      = var.region
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "premium"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = []
  }

  tags = local.tags
}

# ── Private endpoint ────────────────────────────────────────────────

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${local.kv_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.tenant.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dzg-kv"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# ── Bootstrap RBAC for the deployer (CI SP) ─────────────────────────
# RBAC mode means subscription Contributor isn't enough on its own
# to create + manage the CMK key; explicitly grant the deployer
# Crypto Officer at the vault scope. AAD propagation is eventually
# consistent — wait 60 s before the key resource depends on this.

resource "azurerm_role_assignment" "deployer_crypto_officer" {
  scope                = azurerm_key_vault.tenant.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_crypto_officer]
  create_duration = "60s"
}

# ── CMK key for tenant-postgres ─────────────────────────────────────
# RSA 3072 matches the platform pattern. PG Flex CMK requires
# RSA-2048+ in either the software or HSM key types; HSM is the
# Premium SKU's default for new RSA keys (azurerm 4.x picks HSM
# automatically when the vault is Premium and key_type=RSA).
# Rotation: 90 days; expire after 1 year; notify 30 days before.

resource "azurerm_key_vault_key" "cmk" {
  name         = "key-${var.tenant_id}-cmk"
  key_vault_id = azurerm_key_vault.tenant.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_after_creation = "P90D"
    }
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"
  }

  tags = local.tags

  depends_on = [time_sleep.wait_for_kv_rbac]
}
