#!/bin/bash

# Check if user is root

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   echo "Please run $ sudo bash then rerun this script"
   exit 1
fi

source ~/setup_paramrc

source ~/openrc

cat >> ~/.bashrc <<EOF
source ~/openrc
EOF

source ~/.bashrc

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE nova_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON nova_db.* TO 'nova'@'%' IDENTIFIED BY 'nova';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON nova_db.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"

echo "
#####################################
	Install Nova
#####################################
"
sleep 2

# Check to install nova-compute-kvm or nova-compute-qemu

if [ $HYPERVISOR == "qemu" ]; then
	apt-get -y install nova-compute nova-compute-qemu
else
	apt-get -y install nova-compute nova-compute-kvm
fi

apt-get install -y rabbitmq-server nova-volume nova-novncproxy nova-api nova-ajax-console-proxy nova-cert nova-consoleauth nova-doc nova-scheduler nova-network

# Add below to forward traffic to $PUBLIC_NIC

cat > /etc/network/if-pre-up.d/iptablesload <<EOF
#!/bin/sh
iptables -t nat -A POSTROUTING -o $PUBLIC_NIC -j MASQUERADE
exit 0
EOF

chmod +x /etc/network/if-pre-up.d/iptablesload

# Change owner and permission for /etc/nova/

groupadd nova
usermod -g nova nova
chown -R nova:nova /etc/nova
chmod 644 /etc/nova/nova.conf

# Update /etc/nova/api-paste.ini
sed -i "s/127.0.0.1/$IP/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_TENANT_NAME%/$SERVICE_TENANT/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_USER%/nova/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_PASSWORD%/nova/g" /etc/nova/api-paste.ini

# Update hypervisor in nova-compute.conf

if [ $HYPERVISOR == "qemu" ]; then
	sed -i 's/kvm/qemu/g' /etc/nova/nova-compute.conf
fi

# Update nova.conf

cat > /etc/nova/nova.conf <<EOF
[DEFAULT]

# LOG/STATE
verbose=True
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
allow_admin_api=true
# AUTHENTICATION
use_deprecated_auth=false
auth_strategy=keystone
keystone_ec2_url=http://$IP:5000/v2.0/ec2tokens

# SCHEDULER
scheduler_driver=nova.scheduler.simple.SimpleScheduler
compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# DATABASE
sql_connection=mysql://nova:nova@$IP/nova_db

# NETWORK
network_manager=nova.network.manager.FlatDHCPManager
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
public_interface=$PUBLIC_NIC
flat_interface=$PRIVATE_NIC
flat_network_bridge=br100
fixed_range=$VMNET_IP_RANGE
network_size=$VMNET_NET_SIZE
#flat_network_dhcp_start=$VMNET_IP_START
flat_injected=False
#routing_source_ip=$IP
force_dhcp_release=True
#iscsi_helper=ietadm
#iscsi_ip_address=$IP
#my_ip=$IP
#multi_host=True
#firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

# NOVNC
novnc_enabled=true
novncproxy_base_url=http://$CONTROLLER_PUBLIC_IP:6080/vnc_auto.html
novncproxy_port=6080
#xvpvncproxy_base_url=http://$IP:6081/console
vncserver_listen=0.0.0.0
vncserver_proxyclient_address=127.0.0.1

# APIs
#osapi_compute_extension=nova.api.openstack.compute.contrib.standard_extensions
s3_host=$IP
ec2_host=$IP
ec2_dmz_host=$IP
cc_host=$IP
metadata_host=$IP
#enabled_apis=ec2,osapi_compute,metadata
nova_url=http://$IP:8774/v1.1/
ec2_url=http://$IP:8773/services/Cloud
#volume_api_class=nova.volume.cinder.API

# RABBIT
rabbit_host=$IP

# GLANCE
glance_api_servers=$IP:9292
image_service=nova.image.glance.GlanceImageService

# COMPUTE
#connection_type=libvirt
compute_driver=libvirt.LibvirtDriver
libvirt_type=qemu
libvirt_cpu_mode=none
#allow_resize_to_same_host=True
#libvirt_use_virtio_for_bridges=true
start_guests_on_host_boot=True
resume_guests_state_on_host_boot=True
api_paste_config=/etc/nova/api-paste.ini
allow_admin_api=True
use_deprecated_auth=False
rootwrap_config=/etc/nova/rootwrap.conf
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
#instance_name_template=instance-%08x

# CINDER
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
EOF

# Config nova-volume
#~ vgremove nova-volumes $NOVA_VOLUME # just for sure, if the 1st time this script failed, then rerun...
#~ 
#~ pvcreate -ff -y $NOVA_VOLUME # if rerun the script we need force option
#~ vgcreate nova-volumes $NOVA_VOLUME

cat > ~/nova_restart <<EOF
sudo restart libvirt-bin
sudo /etc/init.d/rabbitmq-server restart
for i in nova-network nova-compute nova-api nova-objectstore nova-scheduler nova-volume nova-consoleauth nova-cert nova-novncproxy
do
sudo service "\$i" restart # need \ before $ to make it a normal charactor not variable
done
EOF

chmod +x ~/nova_restart

# Sync nova_db
  
~/nova_restart
sleep 3
 nova-manage db sync
sleep 3
~/nova_restart
sleep 3
nova-manage service list

# Create fixed and floating ips

nova-manage network create private --fixed_range_v4=$VMNET_IP_RANGE --num_networks=1 --bridge=br100 --bridge_interface=$PRIVATE_NIC --network_size=$VMNET_NET_SIZE --multi_host=T

#nova-manage fixed reserve --address=$VMNET_IP_START

nova-manage floating create --ip_range=$PUBLIC_IP_RANGE

# Define security rules

nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default tcp 80 80 0.0.0.0/0

# Create key pair

mkdir ~/key
cd ~/key
nova keypair-add mykeypair > mykeypair.pem
chmod 600 mykeypair.pem
cd

