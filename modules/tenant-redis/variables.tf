variable "tenant_id"           { type = string }
variable "region"              { type = string }
variable "resource_group_name" { type = string }

# PE subnet from tenant-network.snet-redis.
variable "subnet_id" { type = string }

# privatelink.redis.cache.windows.net from
# tenant-network.private_dns_zone_ids["redis"].
variable "private_dns_zone_id" { type = string }

# Premium tier capacity (P1=1, P2=2, P3=3, P4=4, P5=5).
# Default P1 = 6 GB; bump per tenant via tfvars when call volume
# justifies it.
variable "capacity" {
  type    = number
  default = 1
}
