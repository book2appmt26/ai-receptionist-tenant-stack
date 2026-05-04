variable "tenant_id"        { type = string }
variable "tenant_vnet_id"   { type = string }
variable "tenant_vnet_name" { type = string }
# Compute VNet (in the platform sub) is referenced via the airxtfstate
# remote state — implementation lands with task 2.9.
