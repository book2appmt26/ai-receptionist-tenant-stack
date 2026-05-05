output "storage_id" {
  value = azurerm_storage_account.tenant.id
}

output "storage_name" {
  value = azurerm_storage_account.tenant.name
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.tenant.primary_blob_endpoint
}

# True iff `recordings` container + lifecycle policy were created.
# Useful for downstream wiring that should only target a tenant once
# recording is actually on.
output "recording_enabled" {
  value = var.recording_enabled
}
