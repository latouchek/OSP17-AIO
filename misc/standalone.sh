export VIP=192.168.123.3
export IP=192.168.123.2
export NETMASK=24
export GATEWAY=192.168.123.1
export INTERFACE=eth1
export DNS_SERVER1=192.168.123.1
export DNS_SERVER2=8.8.8.8

openstack tripleo container image prepare default --output-env-file $HOME/containers-prepare-parameters.yaml
sudo tee -a $HOME/containers-prepare-parameters.yaml << EOF
  ContainerImageRegistryCredentials:
    registry.redhat.io:
      youredhatlogin: 'yourredhatpasswd'
  ContainerImageRegistryLogin: true
EOF

cat <<EOF > $HOME/standalone_parameters.yaml
parameter_defaults:
  CloudName: $IP
  CloudDomain: localdomain
  ControlPlaneStaticRoutes: []
  Debug: true
  DeploymentUser: $USER
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
    - $IP:8787
  NeutronPublicInterface: $INTERFACE
  NeutronDnsDomain: localdomain
  NeutronBridgeMappings: datacentre:br-ctlplane
  NeutronPhysicalBridge: br-ctlplane
  NeutronNetworkType: ["geneve","vlan","flat"]
  NeutronNetworkVLANRanges: "datacentre:1:1000"
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: $HOME
  StandaloneLocalMtu: 1500
  NovaComputeLibvirtType: qemu
EOF

sudo podman login registry.redhat.io 

sudo openstack tripleo deploy \
  --templates \
  --local-ip=$IP/$NETMASK \
  --control-virtual-ip=$VIP \
  -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml \
  -r /usr/share/openstack-tripleo-heat-templates/roles/Standalone.yaml \
  -e $HOME/containers-prepare-parameters.yaml \
  -e $HOME/standalone_parameters.yaml \
  --output-dir $HOME \
  --standalone