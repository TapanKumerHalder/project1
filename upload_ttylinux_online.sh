

# Scource the openrc file # just make sure

source ~/bashrc
source ~/openrc

# Create a new folder to store all the image like tty-linux

cd ~
mkdir img
cd ~/img


# Download this by wget

wget http://smoser.brickies.net/ubuntu/ttylinux-uec/mirror/ttylinux-x86_64-12.1.iso.gz

# Untar this file

tar zxvf ttylinux-x86_64-12.1.iso.gz

# Upload to glance

glance add name="tty-linux-kernel" disk_format=aki container_format=aki < ttylinux-x86_64-vmlinuz
kernelID=$(glance index | grep -i tty-linux-kernel | awk '{print $1}')

glance add name="tty-linux-ramdisk" disk_format=ari container_format=ari < ttylinux-x86_64-loader 
ramdiskID=$(glance index | grep -i tty-linux-ramdisk | awk '{print $1}')

glance add name="tty-linux" disk_format=ami container_format=ami kernel_id=$kernelID ramdisk_id=$ramdishID < ttylinux-x86_64-12.1.iso.gz

# List the images

glance index

###===END===###
