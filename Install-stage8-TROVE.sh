apt-get install python-trove python-troveclient python-glanceclient trove-common trove-api trove-taskmanager

source ~/admin-openrc.sh

# trove-manage --config-file /etc/trove/trove.conf datastore_version_update \
  #mysql mysql-5.5 mysql glance_image_ID mysql-server-5.5 1


keystone user-create --name trove --pass TROVE_PASS
keystone user-role-add --user trove --tenant service --role admin


keystone service-create --name trove --type database \
  --description "OpenStack Database Service"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ trove / {print $2}') \
  --publicurl http://controller:8779/v1.0/%\(tenant_id\)s \
  --internalurl http://controller:8779/v1.0/%\(tenant_id\)s \
  --adminurl http://controller:8779/v1.0/%\(tenant_id\)s \
  --region regionOne

service trove-api restart
service trove-taskmanager restart
service trove-conductor restart
