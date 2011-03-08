#!/bin/sh
#
# Install Debian Squeeze on DockStar

# Copyright (c) 2010 Jeff Doozan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.



# Definitions

HOSTNAME=debian

# debootstrap configuration
RELEASE=squeeze
VARIANT=minbase
EMB_MIRROR=http://www.emdebian.org/grip/

# if you want to install additional packages, add them to the end of this list
# Note: Not all packages are available in the embdebian repository
EXTRA_PACKAGES=linux-image-2.6-kirkwood,linux-base,initramfs-tools,module-init-tools,udev,mtd-utils,netbase,ifupdown,iproute,dhcp3-client,openssh-server,iputils-ping,wget,net-tools,ntpdate,vim-tiny,emdebian-archive-keyring,debian-archive-keyring
KERNEL_VERSION=2.6.32-5-kirkwood


# Download URLs
MIRROR="http://jeff.doozan.com/debian"
DEB_MIRROR="http://ftp.us.debian.org/debian"

URL_MKE2FS="$MIRROR/mke2fs"
URL_UBOOT="$MIRROR/uboot/install_uboot_mtd0.sh"

URL_DEBOOTSTRAP="$DEB_MIRROR/pool/main/d/debootstrap/debootstrap_1.0.26_all.deb"
URL_MKIMAGE="$DEB_MIRROR/pool/main/u/uboot-mkimage/uboot-mkimage_0.4_armel.deb"
URL_ENVTOOLS="$DEB_MIRROR/pool/main/u/uboot-envtools/uboot-envtools_20081215-2_armel.deb"

# Where should the temporary 'debian root' be mounted
ROOT=/tmp/debian







#########################################################
#  There are no user-serviceable parts below this line
#########################################################

ROOT_DEV=/dev/sda1 # Don't change this, uboot expects to boot from here

# Stop the pogoplug engine
killall -q hbwd

echo ""
echo ""
echo ""

if ! which chroot >/dev/null; then
  echo "ERROR. CANNOT CONTINUE."
  echo ""
  echo "Cannot find chroot.  You need to update your PATH."
  echo "Run the following command and then run this script again:"
  echo ""
  echo 'export PATH=$PATH:/sbin:/usr/sbin'
  echo ""
  exit 1
fi


echo "!!!!!!  DANGER DANGER DANGER DANGER DANGER DANGER  !!!!!!"
echo ""
echo "This script will replace the bootloader on /dev/mtd0."
echo ""
echo "If you lose power while the bootloader is being flashed,"
echo "your device could be left in an unusable state."
echo ""
echo ""
echo "This script will configure your Dockstar to boot EmDebian Squeeze (Grip)"
echo "from a USB device.  Before running this script, you should have"
echo "used fdisk to create the following partitions:"
echo ""
echo "/dev/sda1 (Linux ext2, at least 300MB)"
echo ""
echo "This script will DESTROY ALL EXISTING DATA on /dev/sda1"
echo "Please double check that the device on /dev/sda1 is the correct device."
echo ""
echo "By typing ok, you agree to assume all liabilities and risks"
echo "associated with running this installer."
echo ""
echo -n "If everything looks good, type 'ok' to continue: "


read IS_OK
if [ "$IS_OK" != "OK" -a "$IS_OK" != "Ok" -a "$IS_OK" != "ok" ];
then
  echo "You did not type 'ok', exiting installer."
  echo "Your system has not been modified."
  exit
fi




##########
##########
#
# Install uBoot on /dev/mtd0
#
##########
##########


# Get the uBoot install script
if [ ! -f /tmp/install_uboot_mtd0.sh ];
then
  wget -P /tmp $URL_UBOOT
  chmod +x /tmp/install_uboot_mtd0.sh
fi

echo "Installing Bootloader"
/tmp/install_uboot_mtd0.sh --noprompt



##########
##########
#
# Format /dev/sda
#
##########
##########

# Get the source directory
SRC=$ROOT

# Create the mount point if it doesn't already exist
if [ ! -f $ROOT ];
then
  mkdir -p $ROOT
else
  umount $ROOT > /dev/null 2>&1
fi

if [ ! -f /sbin/mke2fs ];
then
  mount -o rw,remount /
  wget -P /sbin $URL_MKE2FS
  chmod +x /sbin/mke2fs
  mount -o ro,remount /
fi

/sbin/mke2fs $ROOT_DEV

mount $ROOT_DEV $ROOT

if [ "$?" -ne "0" ]; then
  echo "Could not mount $ROOT_DEV on $ROOT"
  exit 1
fi


##########
##########
#
# Download debootstrap
#
##########
##########

if [ ! -e /usr/sbin/debootstrap ]; then
  mkdir /tmp/debootstrap
  cd /tmp/debootstrap
  wget -O debootstrap.deb $URL_DEBOOTSTRAP
  ar xv debootstrap.deb
  tar -xzvf data.tar.gz

  mount -o rw,remount /
  mv ./usr/sbin/debootstrap /usr/sbin
  mv ./usr/share/debootstrap /usr/share
  wget -O /usr/share/debootstrap/pkgdetails http://jeff.doozan.com/debian/pkgdetails
  chmod +x /usr/share/debootstrap/pkgdetails
  mount -o ro,remount /
fi
                                                          

##########
##########
#
# Run debootstrap
#
##########
##########

echo ""
echo ""
echo "# Starting debootstrap installation"

# Embdebian Grip (Squeeze)

mkdir -p $ROOT/usr/share/info
mkdir -p $ROOT/usr/share/man/man1
/usr/sbin/debootstrap --verbose --arch=armel --variant=$VARIANT --include=$EXTRA_PACKAGES $RELEASE $ROOT $EMB_MIRROR

if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See $ROOT/debootstrap/debootstrap.log for more information."
  exit 1
fi

cat <<END > $ROOT/etc/apt/apt.conf
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END


# Install packages from official debian repository
#echo "deb $DEB_MIRROR $RELEASE main" >> $ROOT/etc/apt/sources.list
chroot $ROOT /usr/bin/apt-get update
#chroot $ROOT /usr/bin/apt-get -y --force-yes install $DEB_PACKAGES
chroot $ROOT /usr/bin/apt-get -y --force-yes upgrade
chroot $ROOT /usr/bin/apt-get clean

#Install mkimage
wget -O $ROOT/tmp/mkimage.deb $URL_MKIMAGE
chroot $ROOT /usr/bin/dpkg -i /tmp/mkimage.deb
rm $ROOT/tmp/mkimage.deb

#Install envtools
wget -O $ROOT/tmp/envtools.deb $URL_ENVTOOLS
chroot $ROOT /usr/bin/dpkg -i /tmp/envtools.deb
rm $ROOT/tmp/envtools.deb

#Prep the kernel images for uBoot
chroot $ROOT /usr/bin/mkimage -A arm -O linux -T kernel  -C none -a 0x00008000 -e 0x00008000 -n Linux-$KERNEL_VERSION -d /boot/vmlinuz-$KERNEL_VERSION /boot/uImage
chroot $ROOT /usr/bin/mkimage -A arm -O linux -T ramdisk -C gzip -a 0x00000000 -e 0x00000000 -n initramfs-$KERNEL_VERSION -d /boot/initrd.img-$KERNEL_VERSION /boot/uInitrd

#Remove the non-image kernel files
rm $ROOT/boot/vmlinuz-$KERNEL_VERSION
rm $ROOT/boot/initrd.img-$KERNEL_VERSION


##########
##########
#
# Configure essential system files
#
##########
##########

#configure hostname and add it to /etc/hosts
echo $HOSTNAME > $ROOT/etc/hostname
sed -i "s/^\(127.0.0.1.*\)/\1 $HOSTNAME/" $ROOT/etc/hosts

echo LANG=C > $ROOT/etc/default/locale

cat <<END > $ROOT/etc/fw_env.config
# MTD device name	Device offset	Env. size	Flash sector size	Number of sectors
/dev/mtd0         0xc0000       0x20000   0x20000
END

cat <<END > $ROOT/etc/network/interfaces
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
END

echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux' >> $ROOT/etc/inittab
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' $ROOT/etc/inittab

# root password is 'root'
echo "root:\$1\$XPo5vyFS\$iJPfS62vFNO09QUIUknpm.:14360:0:99999:7:::" > $ROOT/etc/shadow


##########
##########
#
# Configure system as read-only
#
##########
##########


cat <<END > $ROOT/etc/fstab
/dev/root  /                 ext2  noatime,ro   0 1

# /tmp (and others) are mounted from /sbin/init-ro

# un-comment the next line to store /etc on external drive
#/dev/sda1 /etc              ext2  noatime      0 0

# uncommend the next two lines to store apt files on external drive
#/dev/sda2 /var/cache/apt/lists    ext2  noatime      0 0
#/dev/sda3 /var/lib/apt            ext2  noatime      0 0

END

cat <<END > $ROOT/etc/kernel/postinst.d/zz-flash-kernel
#!/bin/sh

version="$1"
bootopt=""

# passing the kernel version is required
[ -z "${version}" ] && exit 0

echo "Running flash-kernel ${version}"
flash-kernel ${version}
END
chmod +x $ROOT/etc/kernel/postinst.d/zz-flash-kernel

# Create /sbin/init-ro script mount serveral directories as tmfps

cat <<END > $ROOT/sbin/init-ro
#!/bin/bash
DIRS="/tmp /var/log /var/run /var/lock /var/tmp /var/lib/urandom /var/lib/dhcp /etc/network/run"
for DIR in \$DIRS; do
  echo "Mounting \$DIR as tmpfs"
  mount -n -t tmpfs tmpfs \$DIR
  if [ -d "\$DIR-saved" ]; then
    echo "Restoring \$DIR-saved to \$DIR"
    tar -C "\$DIR-saved" -cf - ./ | tar -C "\$DIR" -xpf -
  fi
done

echo "nameserver 4.2.2.1" > /var/tmp/resolv.conf
touch /var/lib/dhcp/dhcpd.leases

exec /sbin/init
END
chmod +x $ROOT/sbin/init-ro


# Configure dhcp-client to write resolv.conf to /tmp instead of /etc
sed -i 's/\/etc\/resolv.conf/\/var\/tmp\/resolv.conf/' $ROOT/sbin/dhclient-script > /dev/null 2>&1
rm $ROOT/etc/resolv.conf
ln -s /var/tmp/resolv.conf $ROOT/etc/resolv.conf


# make /etc/network/run/ a symlink to /tmp/network/
rm -rf $ROOT/etc/network/run
ln -s /var/tmp/network $ROOT/etc/network/run


# Fixes from http://wiki.debian.org/ReadonlyRoot

rm $ROOT/etc/blkid.tab  > /dev/null 2>&1
ln -s /dev/null $ROOT/etc/blkid.tab

rm $ROOT/etc/mtab  > /dev/null 2>&1
ln -s /proc/mounts $ROOT/etc/mtab

rm $ROOT/etc/rcS.d/S12udev-mtab

rm -rf $ROOT/var/log/*

##### Configure boot environment

fw_setenv usb_root "$ROOT_DEV ro"
fw_setenv usb_set_bootargs 'setenv bootargs console=$console root=$usb_root rootdelay=$usb_rootdelay rootfstype=$usb_rootfstype $mtdparts init=/sbin/init-ro'

##### All Done

cd /
umount $ROOT > /dev/null 2>&1

echo ""
echo ""
echo ""
echo ""
echo "Installation complete"
echo ""
echo "You can now reboot your device into Debian."
echo "If your device does not start Debian after rebooting,"
echo "you may need to restart the device by disconnecting the power."
echo ""
echo -n "Reboot now? [Y/n] "

read IN
if [ "$IN" = "" -o "$IN" = "y" -o "$IN" = "Y" ];
then
  /sbin/reboot
fi

