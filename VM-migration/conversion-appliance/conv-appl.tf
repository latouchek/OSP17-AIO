terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
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

data "openstack_images_image_v2" "rhel9" {
  name        = "rhel9"
  most_recent = true
}

data "openstack_networking_network_v2" "provider_network_vlan20" {
  name = "provider_network_vlan20"
}

resource "openstack_blockstorage_volume_v3" "boot_volume" {
  name     = "conversion-appliance-boot-volume"
  size     = 20
  image_id = data.openstack_images_image_v2.rhel9.id
}


resource "openstack_compute_instance_v2" "conversion-appliance" {
  name          = "conversion-appliance"
  flavor_name   = "m1.medium"
  key_pair      = "key1"
  security_groups = ["all-traffic"]

  network {
    name = data.openstack_networking_network_v2.provider_network_vlan20.name
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.boot_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }
  metadata = {
    "os-parameters" = "edd=off"
  }
  config_drive = true

  user_data = file("${path.module}/user_data_conversion_appliance.yaml")
}
