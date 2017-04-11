sudo apt-get update
sudo apt-get install -y curl gcc memcached rsync sqlite3 xfsprogs git-core libffi-dev python-setuptools
sudo apt-get install python-coverage python-dev python-nose python-simplejson python-xattr python-eventlet python-greenlet python-pastedeploy python-netifaces python-pip python-dnspython python-mock

sudo mkdir -p /swift-disks /swift-mounts /swift-source /var/run/swift /swift-mounts/disk{1,2,3,4}
sudo chown -R swift:swift /var/run/swift /swift-disks /swift-mounts /swift-source
sudo mkdir -p /srv/
sudo chown -R swift:swift /srv

sudo mkdir -p /srv
sudo ln -s /swift-mounts/disk1 /srv/1;
sudo ln -s /swift-mounts/disk2 /srv/2;
sudo ln -s /swift-mounts/disk3 /srv/3;
sudo ln -s /swift-mounts/disk4 /srv/4;
sudo mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4



sudo truncate -s 2GB /swift-disks/disk1
sudo truncate -s 2GB /swift-disks/disk2
sudo truncate -s 2GB /swift-disks/disk3
sudo truncate -s 2GB /swift-disks/disk4

sudo mkfs.xfs /swift-disks/disk1
sudo mkfs.xfs /swift-disks/disk2
sudo mkfs.xfs /swift-disks/disk3
sudo mkfs.xfs /swift-disks/disk4

cat << EOF | sudo tee -a /etc/fstab
/swift-disks/disk1 /swift-mounts/disk1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
/swift-disks/disk2 /swift-mounts/disk2 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
/swift-disks/disk3 /swift-mounts/disk3 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
/swift-disks/disk4 /swift-mounts/disk4 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
EOF

cd /swift-source
git clone https://github.com/openstack/python-swiftclient.git
cd python-swiftclient
sudo pip install -r requirements.txt
sudo python setup.py develop

cd /swift-source
git clone https://github.com/openstack/swift.git
cd swift
sudo pip install -r requirements.txt
sudo pip install -r test-requirements.txt
sudo python setup.py develop

sudo cp /swift-source/swift/doc/saio/rsyncd.conf /etc/
sudo sed -i "s/<your-user-name>/swift/" /etc/rsyncd.conf

echo "RSYNC_ENABLE=true" | sudo tee /etc/default/rsync
sudo service rsync restart
rsync rsync://pub@localhost/
sudo service memcached start
sudo mv /etc/swift{,.old}


sudo cp -r /swift-source/swift/doc/saio/swift /etc/swift
sudo chown -R swift:swift /etc/swift
find /etc/swift/ -name \*.conf | xargs sudo sed -i "s/<your-user-name>/swift/"

mkdir -p $HOME/bin
cp -r /swift-source/swift/doc/saio/bin/ ~/bin/
chmod +x $HOME/bin/*

sudo cp /swift-source/swift/test/sample.conf /etc/swift/test.conf
echo "export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf" >> $HOME/.bashrc
echo "export PATH=${PATH}:$HOME/bin" >> $HOME/.bashrc
. ~/.bashrc

/swift-source/swift/doc/saio/bin/remakerings
/swift-source/swift/.unittests
/swift-source/swift/doc/saio/bin/startmain

#tast
curl -v -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8080/auth/v1.0

swift -A http://127.0.0.1:8080/auth/v1.0 -U test:tester -K testing stat

#Run the functional tests
#/swift-source/swift/.functests

#Run the probe tests
#/swift-source/swift/.probetests



