variable "tenant_id"           { type = string }
variable "region"              { type = string }
variable "resource_group_name" { type = string }
variable "recording_enabled" {
  type    = bool
  default = false
}
