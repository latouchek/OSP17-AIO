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

data "openstack_images_image_v2" "centos" {
  name        = "fed40"
  most_recent = true
}

data "openstack_networking_network_v2" "provider_network_vlan20" {
  name = "provider_network_vlan20"
}

resource "openstack_blockstorage_volume_v3" "boot_volume" {
  name     = "centos-test-boot-volume"
  size     = 10
  image_id = data.openstack_images_image_v2.centos.id
}

resource "openstack_blockstorage_volume_v3" "data_volume" {
  name = "centos-test-data-volume"
  size = 10
}

resource "openstack_compute_instance_v2" "centos_test" {
  name          = "centos-test"
  flavor_name   = "m1.small"
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

  user_data = <<-EOF
  #cloud-config
  users:
    - name: changeme
      ssh-authorized-keys:
        - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEIQXj3BJeJFoBn3EQ5WhT31r8HLpmiAdFYIcug3Xqd ##change me
      sudo: ["ALL=(ALL) NOPASSWD:ALL"]
      groups: sudo
      shell: /bin/bash

  # fs_setup:
  #   - label: None
  #     filesystem: 'ext4'
  #     device: '/dev/vdb'
  #     partition: 'auto'
  # bootcmd:
  #   - echo 'GRUB_CMDLINE_LINUX="edd=off"' >> /etc/default/grub
  #   - grub2-mkconfig -o /boot/grub2/grub.cfg

  # mounts:
  #   - [ /dev/vdb, /data-test, "ext4", "defaults,noatime" ]

  # mount_default_fields: [ None, None, "ext4", "defaults,noatime", "0","2" ]
  EOF
}

resource "openstack_compute_volume_attach_v2" "attach_data_volume" {
  instance_id = openstack_compute_instance_v2.centos_test.id
  volume_id   = openstack_blockstorage_volume_v3.data_volume.id
}
