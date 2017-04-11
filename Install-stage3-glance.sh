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
####################################
	Install Glance
####################################
"
sleep 2

apt-get install -y glance

rm /var/lib/glance/glance.sqlite

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE glance_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON glance_db.* TO 'glance'@'%' IDENTIFIED BY 'glance';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON glance_db.* TO 'glance'@'localhost' IDENTIFIED BY 'glance';"

# Update /etc/glance/glance-api-paste.ini, /etc/glance/glance-registry-paste.ini

#~ sed -i "s/%SERVICE_TENANT_NAME%/$SERVICE_TENANT/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini
#~ sed -i "s/%SERVICE_USER%/glance/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini
#~ sed -i "s/%SERVICE_PASSWORD%/glance/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini

cat >> /etc/glance/glance-api-paste.ini <<EOF
admin_tenant_name = $SERVICE_TENANT
admin_user = glance
admin_password = glance
EOF

cat >> /etc/glance/glance-registry-paste.ini <<EOF
[filter:authtoken]
admin_tenant_name = $SERVICE_TENANT
admin_user = glance
admin_password = glance
EOF

# update authtoken
sed -i "s/pipeline = unauthenticated-context registryapp/pipeline = authtoken auth-context context registryapp/g" /etc/glance/glance-registry-paste.ini

# Update /etc/glance/glance-registry.conf

sed -i "s|sql_connection = sqlite:////var/lib/glance/glance.sqlite|sql_connection = mysql://glance:glance@$IP/glance_db|g" /etc/glance/glance-registry.conf

# Add to the and of /etc/glance/glance-registry.conf and /etc/glance/glance-api.conf

cat >> /etc/glance/glance-registry.conf <<EOF
flavor = keystone
EOF

cat >> /etc/glance/glance-api.conf <<EOF
flavor = keystone
EOF

# Sync glance_db

restart glance-api
restart glance-registry

sleep 3

glance-manage version_control 0
glance-manage db_sync

sleep 3

restart glance-api
restart glance-registry

