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

echo "
#####################################
	Install Horizon
#####################################
"
sleep 2

apt-get install --no-install-recommends -y memcached libapache2-mod-wsgi openstack-dashboard novnc

# Disable Quantum
cat >> /etc/openstack-dashboard/local_settings.py <<EOF
QUANTUM_ENABLED = False
EOF

# Fix URL - kc modified
sed -i "s|LOGIN_URL='/horizon/|LOGIN_URL='/|g" /etc/openstack-dashboard/local_settings.py
sed -i "s|LOGIN_REDIRECT_URL='/horizon|LOGIN_REDIRECT_URL='/|g" /etc/openstack-dashboard/local_settings.py

# Default istallation uses $IP/horizon to access dashboard
sed -i "s|/horizon|/|g" /etc/apache2/conf.d/openstack-dashboard.conf

service apache2 restart

echo "
#################################################################
#
#    Now you can open your browser and enter your IP: $IP
#    Login with your user and password: $CLOUD_ADMIN@$CLOUD_ADMIN_PASS
#    Enjoy!
#
#################################################################"

#===END===#
