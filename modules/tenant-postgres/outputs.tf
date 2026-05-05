output "postgres_id" {
  value = azurerm_postgresql_flexible_server.tenant.id
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.tenant.fqdn
}

# UA identity backing the server. Useful when other modules (e.g.
# tenant-rbac) need to grant this principal access to other
# tenant-side resources, but the CMK role-assignment lives in this
# module — keeps the consumer/source pair colocated.
output "cmk_identity_principal_id" {
  value = azurerm_user_assigned_identity.cmk.principal_id
}
