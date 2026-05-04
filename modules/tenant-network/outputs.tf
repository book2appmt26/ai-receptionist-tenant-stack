# Placeholder outputs — wired through to the composer; values land
# when the resource bodies are added in task 2.3.

output "resource_group_name" { value = "rg-airx-${var.tenant_id}" }
output "vnet_id"             { value = "" }
output "vnet_name"           { value = "vnet-airx-${var.tenant_id}" }
output "postgres_subnet_id"  { value = "" }
output "redis_subnet_id"     { value = "" }
