export OS_CLOUD=standalone
export GATEWAY=192.168.123.1
export STANDALONE_HOST=192.168.123.2
export PUBLIC_NETWORK_CIDR=192.168.123.0/24
export PRIVATE_NETWORK_CIDR=172.16.16.0/24
export PUBLIC_NET_START=192.168.123.230
export PUBLIC_NET_END=192.168.123.240
export DNS_SERVER=192.168.123.1

openstack network create --external --provider-physical-network datacentre --provider-network-type flat public
openstack network create --internal private
openstack subnet create public-net \
    --subnet-range $PUBLIC_NETWORK_CIDR \
    --no-dhcp \
    --gateway $GATEWAY \
    --allocation-pool start=$PUBLIC_NET_START,end=$PUBLIC_NET_END \
    --network public
openstack subnet create private-net \
    --subnet-range $PRIVATE_NETWORK_CIDR \
    --network private

openstack router create vrouter
openstack router set vrouter --external-gateway public


openstack network create --provider-network-type vlan \
--provider-physical-network datacentre \
--provider-segment 20 \
--share \
provider_network_vlan20

openstack subnet create --network provider_network_vlan20 \
--dhcp \
--allocation-pool start=192.168.20.50,end=192.168.20.100 \
--gateway 192.168.20.1 \
--subnet-range 192.168.20.0/24 \
provider-subnet_vlan20

wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -O cirros.img

openstack image create cirros --file  cirros.img --disk-format qcow2 --container-format bare --public

wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 -O centos9.qcow2

openstack image create centos9 --file  centos9.qcow2 --disk-format qcow2 --container-format bare --public

openstack image create centos9 --file centos9.qcow2 --disk-format qcow2 --container-format bare --public

openstack flavor create --id 1 --ram 2048 --disk 10 --vcpus 1 small

# Créer un flavor "medium" avec un ID spécifique
openstack flavor create --id 2 --ram 4096 --disk 40 --vcpus 2 medium

# Créer un flavor "large" avec un ID spécifique
openstack flavor create --id 3 --ram 8192 --disk 80 --vcpus 4 large

# Créer un flavor "xlarge" avec un ID spécifique
openstack flavor create --id 4 --ram 16384 --disk 160 --vcpus 8 xlarge

# Créer un flavor "xxlarge" avec un ID spécifique
openstack flavor create --id 5 --ram 32768 --disk 320 --vcpus 16 xxlarge

openstack keypair create --public-key ~/.ssh/id_ed25519.pub key1

openstack security group create all-traffic --description "Security group allowing all traffic"

openstack security group rule create --protocol any --ingress all-traffic


openstack server create --flavor m1.tiny --image cirros --network provider_network_vlan20 --security-group default --key-name key1 cirros-test

openstack server create --flavor m1.small --image centos --network provider_network_vlan20 --security-group default --key-name key1 centos-test

