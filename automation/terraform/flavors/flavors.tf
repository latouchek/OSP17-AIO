terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "2.1.0"
    }
  }
}

provider "openstack" {
  user_name   = var.openstack_user_name
  tenant_name = var.openstack_tenant_name
  password    = var.openstack_password
  auth_url    = var.openstack_auth_url
  domain_name = "Default"
}

resource "openstack_compute_flavor_v2" "flavorepa" {
  count = length(var.flavorname2)

  name  = var.flavorname2[count.index]
  ram   = var.ram[count.index]
  vcpus = var.vcpu[count.index]
  disk  = var.disk[count.index]
  is_public = true
  extra_specs = {
    "hw:cpu_policy"        = "dedicated",
    "hw:cpu_thread_policy" = "isolate",
    "hw:mem_page_size"     = "1048576",
    "hw:numa_mempolicy"    = "strict",
    "epa"                  = "true"
  }
}
resource "openstack_compute_flavor_v2" "flavor-standard" {
  count = length(var.flavorname)

  name  = var.flavorname[count.index]
  ram   = var.ram[count.index]
  vcpus = var.vcpu[count.index]
  disk  = var.disk[count.index]
  is_public = true
}
