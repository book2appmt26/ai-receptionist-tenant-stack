output "keyvault_id" {
  value = azurerm_key_vault.tenant.id
}

output "vault_uri" {
  value = azurerm_key_vault.tenant.vault_uri
}

# CMK key ID for tenant-postgres (`customer_managed_key.key_vault_key_id`).
# Versioned ID — PG Flex requires the versioned form, not the
# unversioned vault-relative one.
output "cmk_key_id" {
  value = azurerm_key_vault_key.cmk.id
}

# Versionless variant — what `customer_managed_key.key_vault_key_id`
# on Postgres Flex / Storage / Service Bus etc. wants when you want
# auto-rotation to follow the KV rotation policy. tenant-postgres
# (task 2.4) uses this; pinning to a version disables auto-rotation.
output "cmk_key_versionless_id" {
  value = azurerm_key_vault_key.cmk.versionless_id
}
