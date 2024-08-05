##Convert vmdk to qcow2
qemu-img convert -f vmdk -O qcow2 Fedora_64-bit-disk1.vmdk Fedora_64-bit.qcow2
qemu-img convert -f vmdk -O raw Fedora_64-bit-disk1.vmdk Fedora_64-bit.raw

## Copy resuilting qcow2 to glance
openstack image create "Fedora 64-bit" \
--file Fedora_64-bit.qcow2 \
--disk-format qcow2 \
--container-format bare \
--public
## Copy resuilting qcow2 to glance
openstack image create "Fedora 64-bit" \
--file Fedora_64-bit.raw \
--disk-format raw \
--container-format bare \
--public


## Deploy instance from newly created image

openstack server create --flavor m1.small \
--image "Fedora 64-bit" \
--network provider_network_vlan20 \
--key-name key1 \
--security-group all-traffic \
--min 1 \
--max 1 \
Fedora-server
