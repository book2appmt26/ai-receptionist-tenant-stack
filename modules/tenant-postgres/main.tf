# tenant-postgres — PG Flex HA, CMK from tenant KV, private endpoint,
# pgvector extension. EPIC-2 task 2.4.
#
# Skeleton. See modules/tenant-network/main.tf for the contract pattern.

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}
