# tenant-keyvault — RBAC mode, soft-delete + purge protection on,
# CMK key for tenant-postgres. EPIC-2 task 2.6. Skeleton.

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}
