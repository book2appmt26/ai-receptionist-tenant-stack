# tenant-vnet-peering — peer client VNet ↔ our compute VNet, both
# directions. EPIC-2 task 2.9. Skeleton.

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}
