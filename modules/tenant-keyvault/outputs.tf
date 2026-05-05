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
