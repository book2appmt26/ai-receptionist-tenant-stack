variable "tenant_id"           { type = string }
variable "region"              { type = string }
variable "resource_group_name" { type = string }

# PE subnet from tenant-network.snet-storage.
variable "subnet_id" { type = string }

# privatelink.blob.core.windows.net from
# tenant-network.private_dns_zone_ids["storage"].
variable "private_dns_zone_id" { type = string }

variable "recording_enabled" {
  type    = bool
  default = false
}

# ── Lifecycle defaults (apply only when recording_enabled = true) ───
# 7-year retention default matches the v1 baseline retention assumed
# by the architecture doc. Override per tenant when stricter or
# laxer SLAs apply.

variable "cool_after_days" {
  type    = number
  default = 30
}

variable "archive_after_days" {
  type    = number
  default = 90
}

variable "delete_after_days" {
  type    = number
  default = 2555 # ~7 years
}
