variable "tenant_id" { type = string }
variable "region"    { type = string }
variable "address_space" {
  type    = string
  default = "10.100.0.0/16"
}
