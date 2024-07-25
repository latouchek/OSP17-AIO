# instance the provider
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
provider "libvirt" {
  # uri = "qemu+ssh://root@kvm-ovh/system"
  uri = "qemu:///system"
}
resource "libvirt_volume" "osp17-aio" {
   name   = "osp17-aio.qcow2"
   pool           = "default"
   source = "../../images/rhel9.qcow2"
   format = "qcow2"
 }
resource "libvirt_volume" "volume2" {
  name   = "volume2.qcow2"
  pool           = "default"
  size   = "107374182400"
  format = "qcow2"
}
resource "libvirt_volume" "osp17-aio-boot" {
  name           = "osp17-aio-boot.qcow2"
  base_volume_id = "${libvirt_volume.osp17-aio.id}"
  pool           = "default"
  size           = 42212254720 
}
data "template_file" "user_data" {
  template = "${file("${path.module}/cloud-init-osp17-aio")}"
}

data "template_file" "network_config" {
  template = "${file("${path.module}/network_config-osp17-aio.cfg")}"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "osp17-aio.iso"
  pool           = "default"
  user_data      = "${data.template_file.user_data.rendered}"
  network_config = "${data.template_file.network_config.rendered}"
}

# Create the machine
resource "libvirt_domain" "osp17-aio" {
  name   = "osp17-aio"
  memory = "128000"
  vcpu   = 8
  cpu   {
  mode = "host-passthrough"
  }
  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"



network_interface {
    network_name = "default"
  }
network_interface {
    network_name = "osp-trunk-network"
  }
console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

disk {
    volume_id = "${libvirt_volume.osp17-aio-boot.id}"
  }
disk {
    volume_id = "${libvirt_volume.volume2.id}"
  }
  # disk {
  #   volume_id = "${libvirt_volume.volume3.id}"
  # }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
