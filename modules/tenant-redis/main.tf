# tenant-redis — Premium Redis cache, private endpoint only.
# EPIC-2 task 2.5.
#
# Redis Premium is required because the Private Endpoint subresource
# is Premium-only on Azure Cache for Redis (classic). The orchestrator
# uses Redis for per-call ephemeral state (CallState, TTL'd) — no
# PHI, no long-term storage. P1 (6 GB) is the smallest Premium tier
# and is plenty for the per-tenant call volume v1 expects.
#
# v1 keeps access-key auth. The key is sensitive output of this
# module; downstream consumers fetch it via Key Vault reference (see
# tenant-rbac task 2.10) so the key never lands in plaintext config.
# AAD auth on classic Redis is still rolling to GA across regions —
# revisit in EPIC-7 to either enable
# `redis_configuration.active_directory_authentication_enabled` here
# or migrate the tenant cache to Azure Managed Redis (separate
# resource type) and drop the access-key path entirely.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  cache_name = "redis-airx-${var.tenant_id}"

  tags = {
    CostCenter = "ai-receptionist"
    Tenant     = var.tenant_id
    ManagedBy  = "terraform"
  }
}

resource "azurerm_redis_cache" "tenant" {
  name                          = local.cache_name
  location                      = var.region
  resource_group_name           = var.resource_group_name
  capacity                      = var.capacity
  family                        = "P"
  sku_name                      = "Premium"
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  redis_configuration {
    # Persistence off in v1 — ephemeral per-call state only. Tenants
    # that grow into longer-lived caches enable RDB/AOF via tfvars
    # in EPIC-7 with appropriate storage backing.
    rdb_backup_enabled = false
    aof_backup_enabled = false
  }

  tags = local.tags

  lifecycle {
    # Azure auto-assigns the zone on Premium tiers; ignore_changes
    # prevents terraform from planning to null on subsequent applies.
    ignore_changes = [zones]
  }
}

# ── Private endpoint ────────────────────────────────────────────────

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-${local.cache_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_redis_cache.tenant.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dzg-redis"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
