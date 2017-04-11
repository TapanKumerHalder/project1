################################################################################################
#
#	This script will download Cirros image from:
#   https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
#	Then upload it to glance
#   It is a qcow2 format (for qemu/kvm - high compressed) ~ 9.3 MB
#
#	There're plenty of Ubuntu, CentOs image from Canonical or Stackops,etc
#	but it will take long time to download ( > 200MB ) 
#   so I recommend you download these file first on the client
#	then try to upload it later.
#
################################################################################################

# Scource the openrc file # just for sure if we source the openrc file

source ~/.bashrc
source ~/openrc

# Create a new folder to store all the image like tty-linux

#cd ~
#mkdir img
cd /home/horoppa/

echo "
##############################
Download cirros image to ~/img
##############################
"

#wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

echo "
##############################
Upload cirros image to glance 
##############################
"

glance add is_public=true container_format=bare disk_format=qcow2 distro="ubuntu-12.04-server-64-Bit" name="ubuntu-12.04-server-64-Bit" < ubuntu-12.04-server-cloudimg-amd64-disk1.img
glance add is_public=true container_format=bare disk_format=qcow2 distro="ubuntu-12.04-server-32-Bit" name="ubuntu-12.04-server-32-Bit" < ubuntu-12.04-server-cloudimg-i386-disk1.img
echo "
###############
List the images
###############
"
glance index

echo "
#####################################################################
	This image has default user and password is cirros@cubswin:)
#####################################################################   
"
