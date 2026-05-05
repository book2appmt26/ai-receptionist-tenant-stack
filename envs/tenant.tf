# Per-tenant composer.
#
# Consumed via:
#   tf init -backend-config="container_name=tenant-<tenant_id>"
#   tf apply -var-file=../../tenant-configs/<tenant_id>.tfvars
#
# Each tfvars file in the private `tenant-configs` repo supplies the
# four required inputs below; the composer wires them through to
# every module.
#
# Implementation tracker: EPIC-2 task 2.11. Currently a skeleton —
# modules are stubs (see modules/*/main.tf). Filling them in is
# tasks 2.3 → 2.10.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Backend container is one per tenant. Bootstrap with:
  #   tf init -backend-config="resource_group_name=rg-airx-tfstate" \
  #           -backend-config="storage_account_name=airxtfstate" \
  #           -backend-config="container_name=tenant-<tenant_id>" \
  #           -backend-config="key=tenant.tfstate"
  backend "azurerm" {}
}

# ── Inputs (must be supplied by the tfvars in tenant-configs) ────────

variable "tenant_id" {
  type        = string
  description = "Slug-form tenant ID (lowercase a-z, 0-9, hyphens)."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.tenant_id))
    error_message = "tenant_id must be 3-32 chars, start with a letter, and contain only lowercase a-z, digits, and hyphens."
  }
}

variable "region" {
  type        = string
  description = "Azure region. v1 supports East US 2 only."
  validation {
    condition     = var.region == "eastus2"
    error_message = "Only 'eastus2' is supported in v1 (see negative test T-2.10 in EPIC-2 task list)."
  }
}

variable "client_subscription_id" {
  type        = string
  description = "The CLIENT's Azure subscription ID — distinct from the platform sub. Required for Model C."
}

variable "client_entra_tenant_id" {
  type        = string
  description = "The CLIENT's Entra tenant ID — required for tenant-entra app registration."
}

# ── Providers ────────────────────────────────────────────────────────

provider "azurerm" {
  alias           = "client"
  subscription_id = var.client_subscription_id
  tenant_id       = var.client_entra_tenant_id
  features {}
}

provider "azuread" {
  alias     = "client"
  tenant_id = var.client_entra_tenant_id
}

# ── Modules ──────────────────────────────────────────────────────────
# Each module accepts the tenant_id + region + provider alias and
# produces resources scoped under rg-airx-<tenant_id>-<env> in the
# client's subscription. Wiring is intentionally not active yet —
# module bodies are empty stubs until tasks 2.3 → 2.10 fill them in.

module "tenant_network" {
  source = "../modules/tenant-network"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id = var.tenant_id
  region    = var.region
}

module "tenant_keyvault" {
  source = "../modules/tenant-keyvault"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id           = var.tenant_id
  region              = var.region
  resource_group_name = module.tenant_network.resource_group_name
  subnet_id           = module.tenant_network.keyvault_subnet_id
  private_dns_zone_id = module.tenant_network.private_dns_zone_ids["keyvault"]
}

module "tenant_postgres" {
  source = "../modules/tenant-postgres"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id           = var.tenant_id
  region              = var.region
  resource_group_name = module.tenant_network.resource_group_name
  vnet_id             = module.tenant_network.vnet_id
  subnet_id           = module.tenant_network.postgres_subnet_id
  cmk_key_id          = module.tenant_keyvault.cmk_key_id
}

module "tenant_redis" {
  source = "../modules/tenant-redis"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id           = var.tenant_id
  region              = var.region
  resource_group_name = module.tenant_network.resource_group_name
  subnet_id           = module.tenant_network.redis_subnet_id
}

module "tenant_storage" {
  source = "../modules/tenant-storage"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id           = var.tenant_id
  region              = var.region
  resource_group_name = module.tenant_network.resource_group_name
}

module "tenant_entra" {
  source = "../modules/tenant-entra"
  providers = {
    azuread = azuread.client
  }
  tenant_id = var.tenant_id
}

module "tenant_vnet_peering" {
  source = "../modules/tenant-vnet-peering"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id        = var.tenant_id
  tenant_vnet_id   = module.tenant_network.vnet_id
  tenant_vnet_name = module.tenant_network.vnet_name
}

module "tenant_rbac" {
  source = "../modules/tenant-rbac"
  providers = {
    azurerm = azurerm.client
  }
  tenant_id          = var.tenant_id
  postgres_id        = module.tenant_postgres.postgres_id
  redis_id           = module.tenant_redis.redis_id
  keyvault_id        = module.tenant_keyvault.keyvault_id
  storage_id         = module.tenant_storage.storage_id
  entra_principal_id = module.tenant_entra.federated_principal_id
}

# ── Outputs ──────────────────────────────────────────────────────────

output "tenant_id" {
  value = var.tenant_id
}

output "resource_group_name" {
  value = module.tenant_network.resource_group_name
}

output "postgres_fqdn" {
  value     = module.tenant_postgres.fqdn
  sensitive = false
}

output "keyvault_uri" {
  value = module.tenant_keyvault.vault_uri
}
