output "resource_group_name" {
  value = azurerm_resource_group.tenant.name
}

output "vnet_id" {
  value = azurerm_virtual_network.tenant.id
}

output "vnet_name" {
  value = azurerm_virtual_network.tenant.name
}

output "postgres_subnet_id" {
  value = azurerm_subnet.postgres.id
}

output "redis_subnet_id" {
  value = azurerm_subnet.redis.id
}

output "keyvault_subnet_id" {
  value = azurerm_subnet.keyvault.id
}

output "storage_subnet_id" {
  value = azurerm_subnet.storage.id
}

# Map of the four private DNS zones, keyed by service short name
# (postgres / redis / keyvault / storage). Downstream modules (PE
# resources in tenant-postgres, tenant-redis, etc.) reference these
# IDs when wiring `private_dns_zone_group { private_dns_zone_ids }`
# on their PE.
output "private_dns_zone_ids" {
  value = { for k, z in azurerm_private_dns_zone.tenant : k => z.id }
}
