# tenant-network — VNet + subnets + private DNS zones in client sub.
# EPIC-2 task 2.3.
#
# Skeleton. Resources are intentionally not declared yet; this module's
# variables + outputs document the contract the composer (envs/tenant.tf)
# already wires up. Filling in the resource bodies is task 2.3.

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}
