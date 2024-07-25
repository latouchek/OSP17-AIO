variable "openstack_user_name" {
  description = "OpenStack user name"
  type        = string
}

variable "openstack_tenant_name" {
  description = "OpenStack tenant name"
  type        = string
}

variable "openstack_password" {
  description = "OpenStack password"
  type        = string
}

variable "openstack_auth_url" {
  description = "OpenStack authentication URL"
  type        = string
}

variable "flavorname" {
  type    = list(string)
  default = ["m1.tiny", "m1.small", "m1.medium", "m1.large", "m1.xlarge", "m1.xxlarge"]
}

variable "flavorname2" {
  type    = list(string)
  default = ["epa.tiny", "epa.small", "epa.medium", "epa.large", "epa.xlarge", "epa.xxlarge"]
}

variable "ram" {
  type    = list(number)
  default = [512, 2048, 4096, 8192, 16384, 32768]
}

variable "vcpu" {
  type    = list(number)
  default = [1, 2, 4, 8, 12, 16]
}

variable "disk" {
  type    = list(number)
  default = [1, 10, 20, 40, 60, 160]
}
