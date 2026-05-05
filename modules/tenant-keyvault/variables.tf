variable "tenant_id"           { type = string }
variable "region"              { type = string }
variable "resource_group_name" { type = string }

# PE subnet from tenant-network's snet-keyvault output.
variable "subnet_id" { type = string }

# Private DNS zone for `privatelink.vaultcore.azure.net` from
# tenant-network's `private_dns_zone_ids["keyvault"]`.
variable "private_dns_zone_id" { type = string }
