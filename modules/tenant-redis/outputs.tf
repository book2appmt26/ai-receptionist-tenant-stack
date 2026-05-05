output "redis_id" {
  value = azurerm_redis_cache.tenant.id
}

output "hostname" {
  value = azurerm_redis_cache.tenant.hostname
}

output "ssl_port" {
  value = azurerm_redis_cache.tenant.ssl_port
}

# Sensitive — never log this. Downstream wiring (tenant-rbac task
# 2.10) will land it in tenant Key Vault as a Secret so consumers
# can reference it via KV without ever putting plaintext in env or
# Helm values.
output "primary_access_key" {
  value     = azurerm_redis_cache.tenant.primary_access_key
  sensitive = true
}
