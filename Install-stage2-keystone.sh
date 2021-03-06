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
	Install Keystone
#####################################
"
sleep 2

apt-get -y install keystone

echo "Create DATABASE for Keystone"
mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE keystone_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON keystone_db.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON keystone_db.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';"

rm /var/lib/keystone/keystone.db

sed -i 's/# admin_token = ADMIN/admin_token = 012345SECRET99TOKEN012345/g' /etc/keystone/keystone.conf
sed -i "s/# bind_host = 0.0.0.0/bind_host = 0.0.0.0/g" /etc/keystone/keystone.conf
sed -i "s/# public_port = 5000/public_port = 5000/g" /etc/keystone/keystone.conf
sed -i "s/# admin_port = 35357/admin_port = 35357/g" /etc/keystone/keystone.conf
sed -i "s/# compute_port = 8774/compute_port = 8774/g" /etc/keystone/keystone.conf
sed -i "s/# verbose = False/verbose = True/g" /etc/keystone/keystone.conf
sed -i "s/# debug = False/debug = True/g" /etc/keystone/keystone.conf
sed -i "s/# use_syslog = False/use_syslog = False/g" /etc/keystone/keystone.conf
sed -i "s|connection = sqlite:////var/lib/keystone/keystone.db|connection = mysql://keystone:keystone@$IP/keystone_db|g" /etc/keystone/keystone.conf

service keystone restart
sleep 2
keystone-manage db_sync
sleep 2
service keystone restart
sleep 3

KEYSTONE_IP=$IP
SERVICE_ENDPOINT=http://$IP:35357/v2.0/
SERVICE_TOKEN=012345SECRET99TOKEN012345

NOVA_IP=$IP
VOLUME_IP=$IP
GLANCE_IP=$IP
EC2_IP=$IP

SWFIT_IP=$IP1
 

NOVA_PUBLIC_URL="http://$NOVA_IP:8774/v2/%(tenant_id)s"
NOVA_ADMIN_URL=$NOVA_PUBLIC_URL
NOVA_INTERNAL_URL=$NOVA_PUBLIC_URL

VOLUME_PUBLIC_URL="http://$VOLUME_IP:8776/v1/%(tenant_id)s"
VOLUME_ADMIN_URL=$VOLUME_PUBLIC_URL
VOLUME_INTERNAL_URL=$VOLUME_PUBLIC_URL

GLANCE_PUBLIC_URL="http://$GLANCE_IP:9292/v1"
GLANCE_ADMIN_URL=$GLANCE_PUBLIC_URL
GLANCE_INTERNAL_URL=$GLANCE_PUBLIC_URL
 
KEYSTONE_PUBLIC_URL="http://$KEYSTONE_IP:5000/v2.0"
KEYSTONE_ADMIN_URL="http://$KEYSTONE_IP:35357/v2.0"
KEYSTONE_INTERNAL_URL=$KEYSTONE_PUBLIC_URL

EC2_PUBLIC_URL="http://$EC2_IP:8773/services/Cloud"
EC2_ADMIN_URL="http://$EC2_IP:8773/services/Admin"
EC2_INTERNAL_URL=$EC2_PUBLIC_URL


SWFIT_PUBLIC_URL="http://$SWFIT_IP:8080/v1/AUTH_%(tenant_id)s"
SWFIT_ADMIN_URL="http://$SWFIT_IP:8080/v1/"
SWFIT_INTERNAL_URL=$SWFIT_PUBLIC_URL



## Define Admin, Member role and OpenstackDemo tenant
TENANT_ID=$(keystone tenant-create --name $TENANT | grep id | awk '{print $4}')
ADMIN_ROLE=$(keystone role-create --name Admin | grep id | awk '{print $4}')
MEMBER_ROLE=$(keystone role-create --name Member | grep id | awk '{print $4}')

# create user admin
ADMIN_USER=$(keystone user-create --name $CLOUD_ADMIN --tenant-id $TENANT_ID --pass $CLOUD_ADMIN_PASS --email root@localhost --enabled true | grep id | awk '{print $4}')

# grant Admin role to the admin user in the openstackDemo tenant
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $TENANT_ID

## Create Service tenant. This tenant contains all the services that we make known to the service catalog.
SERVICE_TENANT_ID=$(keystone tenant-create --name $SERVICE_TENANT | grep id | awk '{print $4}')

# Create services user in Service tenant
GLANCE_ID=$(keystone user-create --name glance --tenant-id $SERVICE_TENANT_ID --pass glance --enabled true | grep id | awk '{print $4}')
NOVA_ID=$(keystone user-create --name nova --tenant-id $SERVICE_TENANT_ID --pass nova --enabled true | grep id | awk '{print $4}')
EC2_ID=$(keystone user-create --name ec2 --tenant-id $SERVICE_TENANT_ID --pass ec2 --enabled true | grep id | awk '{print $4}')
CINDER_ID=$(keystone user-create --name cinder --tenant-id $SERVICE_TENANT_ID --pass cinder --enabled true | grep id | awk '{print $4}')

SWFIT_ID=$(keystone user-create --name swift --tenant-id $SERVICE_TENANT_ID --pass swift --enabled true | grep id | awk '{print $4}')


# Grant admin role for those service user in Service tenant
for ID in $GLANCE_ID $NOVA_ID $EC2_ID $CINDER_ID $SWFIT_ID $NETWORK_ID
do
keystone user-role-add --user-id $ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE
done

## Define services
KEYSTONE_SERVICE_ID=$(keystone service-create --name keystone --type identity --description 'OpenStack Identity Service' | grep 'id ' | awk '{print $4}')
COMPUTE_SERVICE_ID=$(keystone service-create --name nova --type compute --description 'OpenStack Compute Service' | grep id | awk '{print $4}') 
VOLUME_SERVICE_ID=$(keystone service-create --name volume --type volume --description 'OpenStack Volume Service' | grep id | awk '{print $4}')
GLANCE_SERVICE_ID=$(keystone service-create --name glance --type image --description 'OpenStack Image Service'  | grep id | awk '{print $4}')
EC2_SERVICE_ID=$(keystone service-create --name ec2 --type ec2 --description 'EC2 Service' | grep id | awk '{print $4}')
CINDER_SERVICE_ID=$(keystone service-create --name cinder --type volume --description 'Cinder Service' | grep id | awk '{print $4}')

SWFIT_SERVICE_ID=$(keystone service-create --name swift --type object-store --description 'OpenStack Storage Service' | grep id | awk '{print $4}')


# Create endpoints to these services
keystone endpoint-create --region $REGION --service-id $COMPUTE_SERVICE_ID --publicurl $NOVA_PUBLIC_URL --adminurl $NOVA_ADMIN_URL --internalurl $NOVA_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $VOLUME_SERVICE_ID --publicurl $VOLUME_PUBLIC_URL --adminurl $VOLUME_ADMIN_URL --internalurl $VOLUME_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $KEYSTONE_SERVICE_ID --publicurl $KEYSTONE_PUBLIC_URL --adminurl $KEYSTONE_ADMIN_URL --internalurl $KEYSTONE_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $GLANCE_SERVICE_ID --publicurl $GLANCE_PUBLIC_URL --adminurl $GLANCE_ADMIN_URL --internalurl $GLANCE_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $EC2_SERVICE_ID --publicurl $EC2_PUBLIC_URL --adminurl $EC2_ADMIN_URL --internalurl $EC2_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $CINDER_SERVICE_ID --publicurl $VOLUME_PUBLIC_URL --adminurl $VOLUME_ADMIN_URL --internalurl $VOLUME_INTERNAL_URL

keystone endpoint-create --region $REGION --service-id $SWFIT_SERVICE_ID --publicurl $SWFIT_PUBLIC_URL --adminurl $SWFIT_ADMIN_URL --internalurl $SWFIT_INTERNAL_URL


# Verifying
keystone user-list

