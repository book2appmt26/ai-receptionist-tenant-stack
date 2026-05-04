# tenant-network — VNet + private endpoint subnets + private DNS
# zones in the client's subscription.
#
# EPIC-2 task 2.3.
#
# Layout choices:
# - One /16 per tenant; carve out a /24 at the start for PE subnets
#   so we can grow horizontally without re-IP'ing.
# - PE subnets are /27 (32 addresses each) — Azure's minimum for
#   modern Private Endpoint workloads, plenty for one PE per service.
# - Private DNS zones are PER-TENANT, not shared across tenants. The
#   platform's compute VNet keeps its own zones; the VNet peering
#   set up by tenant-vnet-peering (task 2.9) is what actually lets
#   the orchestrator pod resolve the tenant's private IPs.
# - No NSGs in v1 — PE subnets don't strictly need them and Azure
#   policy (`deny-public-postgres` + friends in the platform repo)
#   already covers the threat model. Add NSGs in EPIC-7 hardening
#   if a real need surfaces.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  rg_name   = "rg-airx-${var.tenant_id}"
  vnet_name = "vnet-airx-${var.tenant_id}"

  tags = {
    CostCenter = "ai-receptionist"
    Tenant     = var.tenant_id
    ManagedBy  = "terraform"
  }

  # Private DNS zones — Azure's published names, one per PE service.
  # The map keys double as cidx-style tags so a future addition is a
  # one-line change.
  private_dns_zones = {
    postgres = "privatelink.postgres.database.azure.com"
    redis    = "privatelink.redis.cache.windows.net"
    keyvault = "privatelink.vaultcore.azure.net"
    storage  = "privatelink.blob.core.windows.net"
  }
}

# ── Resource group ───────────────────────────────────────────────────

resource "azurerm_resource_group" "tenant" {
  name     = local.rg_name
  location = var.region
  tags     = local.tags
}

# ── Virtual network ──────────────────────────────────────────────────

resource "azurerm_virtual_network" "tenant" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.tenant.name
  location            = azurerm_resource_group.tenant.location
  address_space       = [var.address_space]
  tags                = local.tags
}

# ── PE subnets ───────────────────────────────────────────────────────
# Each subnet sized /27 (32 addresses; ~27 usable). PE subnets must
# have `private_endpoint_network_policies_enabled = false` per Azure
# requirements; that's the azurerm 4.x default but spell it out so a
# provider-default change doesn't surprise us.

resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.tenant.name
  virtual_network_name = azurerm_virtual_network.tenant.name
  address_prefixes     = [cidrsubnet(var.address_space, 11, 0)] # 10.100.0.0/27
  private_endpoint_network_policies = "Disabled"
  service_endpoints    = []
}

resource "azurerm_subnet" "redis" {
  name                 = "snet-redis"
  resource_group_name  = azurerm_resource_group.tenant.name
  virtual_network_name = azurerm_virtual_network.tenant.name
  address_prefixes     = [cidrsubnet(var.address_space, 11, 1)] # 10.100.0.32/27
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "keyvault" {
  name                 = "snet-keyvault"
  resource_group_name  = azurerm_resource_group.tenant.name
  virtual_network_name = azurerm_virtual_network.tenant.name
  address_prefixes     = [cidrsubnet(var.address_space, 11, 2)] # 10.100.0.64/27
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "storage" {
  name                 = "snet-storage"
  resource_group_name  = azurerm_resource_group.tenant.name
  virtual_network_name = azurerm_virtual_network.tenant.name
  address_prefixes     = [cidrsubnet(var.address_space, 11, 3)] # 10.100.0.96/27
  private_endpoint_network_policies = "Disabled"
}

# ── Private DNS zones ────────────────────────────────────────────────

resource "azurerm_private_dns_zone" "tenant" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.tenant.name
  tags                = local.tags
}

# Link each zone to the tenant's VNet so PE A records resolve from
# inside it. Cross-VNet resolution (the platform's compute VNet
# resolving these names) is set up by tenant-vnet-peering — task 2.9.
resource "azurerm_private_dns_zone_virtual_network_link" "tenant" {
  for_each              = local.private_dns_zones
  name                  = "link-${each.key}-${var.tenant_id}"
  resource_group_name   = azurerm_resource_group.tenant.name
  private_dns_zone_name = azurerm_private_dns_zone.tenant[each.key].name
  virtual_network_id    = azurerm_virtual_network.tenant.id
  registration_enabled  = false
  tags                  = local.tags
}
