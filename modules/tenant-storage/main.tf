# tenant-storage — Storage account; recording-disabled by default,
# lifecycle policy template ready for activation.
# EPIC-2 task 2.7.
#
# v1 deliberately does NOT create the `recordings` blob container or
# attach the lifecycle policy unless `recording_enabled = true` is
# set in the tenant's tfvars. Storage account itself is always
# provisioned because:
#   - tenant-rbac wants a storage_id to grant role assignments to.
#   - The control-plane app surface assumes per-tenant storage exists
#     even before any recording is captured.
# Activating recording for an existing tenant is therefore a one-line
# tfvars edit + apply, no resource graph reshape.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  # Storage account names are 3-24 chars, lowercase alphanumeric ONLY
  # (no hyphens). Strip hyphens from the tenant slug, truncate, and
  # postfix a 6-char SHA-256 prefix of tenant_id for global uniqueness.
  st_slug = substr(replace(lower(var.tenant_id), "-", ""), 0, 14)
  st_hash = substr(sha256(var.tenant_id), 0, 6)
  st_name = "st${local.st_slug}${local.st_hash}"

  tags = {
    CostCenter = "ai-receptionist"
    Tenant     = var.tenant_id
    ManagedBy  = "terraform"
  }
}

resource "azurerm_storage_account" "tenant" {
  name                = local.st_name
  resource_group_name = var.resource_group_name
  location            = var.region

  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled    = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  shared_access_key_enabled     = false # Entra-only data plane (Constitution IV.3)
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

# ── Private endpoint (blob subresource only — call recordings live
# in blob storage; queue/file/table not in scope for v1) ────────────

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${local.st_name}-blob"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.tenant.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dzg-blob"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# ── Recordings (created only when recording_enabled = true) ─────────
# Container + lifecycle policy together so flipping the flag is a
# single atomic transition. Lifecycle defaults match the v1 retention
# pattern; tenants with longer compliance windows override via tfvars.

resource "azurerm_storage_container" "recordings" {
  count                 = var.recording_enabled ? 1 : 0
  name                  = "recordings"
  storage_account_id    = azurerm_storage_account.tenant.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "recordings" {
  count              = var.recording_enabled ? 1 : 0
  storage_account_id = azurerm_storage_account.tenant.id

  rule {
    name    = "recordings-tiering"
    enabled = true

    filters {
      prefix_match = ["recordings/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        # Cost ladder: Hot for the active operational window, then
        # Cool, then Archive, then delete at the legal retention
        # boundary. Tenants with stricter retention bump these via
        # tfvars; v1 defaults to a 7-year hold.
        tier_to_cool_after_days_since_modification_greater_than    = var.cool_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.archive_after_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }
    }
  }
}
