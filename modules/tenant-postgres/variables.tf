variable "tenant_id"           { type = string }
variable "region"              { type = string }
variable "resource_group_name" { type = string }
variable "vnet_id"             { type = string }
variable "subnet_id"           { type = string }
variable "private_dns_zone_id" { type = string }

# Versionless CMK key id from tenant-keyvault. Versionless lets PG
# Flex auto-rotate alongside the KV rotation policy; pinning to a
# version disables auto-rotation.
variable "cmk_key_versionless_id" { type = string }

# KV id for the role-assignment that grants the CMK identity Crypto
# Service Encryption User on the vault scope.
variable "keyvault_id" { type = string }

# ── Sizing (overridable per tenant via tfvars) ──────────────────────

variable "pg_version" {
  type    = string
  default = "16"
}

# GeneralPurpose+ is required for HA. Smallest GP option keeps v1
# cost low while still allowing the HA + CMK invariants. Bump per
# tenant in tfvars when load profile justifies it.
variable "sku_name" {
  type    = string
  default = "GP_Standard_D2ds_v5"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

variable "high_availability_enabled" {
  type    = bool
  default = true
}

variable "standby_availability_zone" {
  type    = string
  default = "2"
}
