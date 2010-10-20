#!/bin/sh
#
# Install Debian Lenny on DockStar

# Copyright (c) 2010 Jeff Doozan
#
# many thanks to John Tocher for his installation method
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


# Version 1.3   [8/3/2010]  Updated to newer uBoot
# Version 1.2   [7/23/2010] Re-enable dropbear on pogoplug 1.2.1 firmware
# Version 1.1   [7/21/2010] Add option to automatically cleanup pogoplug scripts
# Version 1.0.2 [7/18/2010] More path fixes
# Version 1.0.1 [7/17/2010] Fixed typo in mirror URLs
# Version 1.0   [7/16/2010] Initial Release

# Much of this is shamelessly borrowed from the following sources:
#
# http://www.plugapps.com/index.php5?title=PlugApps:Pogoplug_Setboot
# http://www.cyrius.com/debian/kirkwood/sheevaplug/
# http://ahsoftware.de/dockstar/
# http://bzed.de/posts/2010/05/installing_debian_on_the_guruplug_server_plus/


# Definitions

# Original package sources
#URL_MKE2FS=http://plugapps.com/os/pogoplug/mke2fs
#URL_BLPARAM=http://plugapps.com/os/pogoplug/uboot/blpararm
#URL_DEBIAN_BASE=http://people.debian.org/~tbm/sheevaplug/lenny/base.tar.bz2
#URL_SHEEVA_UIMAGE=http://sheeva.with-linux.com/sheeva/2.6.33/2.6.33-uImage
#URL_SHEEVA_MODULES=http://sheeva.with-linux.com/sheeva/2.6.33/2.6.33-Modules.tar.gz

# Download from package mirror
MIRROR="http://jeff.doozan.com"

URL_MKE2FS="$MIRROR/debian/mke2fs"
URL_BLPARAM="$MIRROR/debian/uboot/blparam"
URL_UBOOT="$MIRROR/debian/uboot/install_uboot_mtd0.sh"
URL_DEBIAN_BASE="$MIRROR/debian/lenny/base.tar.bz2"
URL_SHEEVA_UIMAGE="$MIRROR/debian/lenny/sheeva-2.6.33-uImage"
URL_SHEEVA_MODULES="$MIRROR/debian/lenny/sheeva-2.6.33-Modules.tar.gz"


# Where should the temporary 'debian root' be mounted
ROOT=/tmp/debian















#########################################################
#  There are no user-serviceable parts below this line
#########################################################




echo "!!!!!!  DANGER DANGER DANGER DANGER DANGER DANGER  !!!!!!"
echo ""
echo "This script will replace the bootloader on /dev/mtd0."
echo ""
echo "If you lose power while the bootloader is being flashed,"
echo "your device could be left in an unusable state."
echo ""
echo ""
echo "This script will configure your Dockstar to boot Debian Lenny"
echo "from a USB device.  Before running this script, you should have"
echo "used fdisk to create the following partitions:"
echo ""
echo "/dev/sda1 (Linux ext2, at least 400MB)"
echo "/dev/sda2 (Linux swap, recommended 256MB)"
echo ""
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
  echo "Exiting..."
  exit
fi




# Stop the pogoplug engine
killall -q hbwd

ROOT_DEV=/dev/sda1 # Don't change this, uboot expects to boot from here
SWAP_DEV=/dev/sda2

# Create the mount point if it doesn't already exist
if [ ! -f $ROOT ];
then
  mkdir -p $ROOT
fi


# Get the source directory
SRC=
SRC_OPT=$ROOT
while [ "$SRC" = "" ]; do

  echo ""
  echo ""
  echo ""
  echo "SOURCE FILES"
  echo ""
  echo "Please enter the path to the install files"
  echo "If the install files are not found in the specified directory, they will be downloaded there"
  echo "If you don't care, just press Enter"
  echo ""
  echo -n "Source Path: [$SRC_OPT] "
  read SRC_IN

  if [ "$SRC_IN" != "" ];
  then
    if [ -d "$SRC_IN" ];
    then
      SRC=$SRC_IN
    else
      SRC_OPT=$SRC_IN
    fi
  # User pressed enter, check SRC_OPT
  else
    if [ "$SRC_OPT" != "" -a -d "$SRC_OPT" ];
    then
      SRC=$SRC_OPT
    fi
  fi

done




##########
##########
#
# Install new uBoot on mtd0
#
##########
##########


echo ""
echo ""

# Get the uBoot install script
if [ ! -f $SRC/install_uboot_mtd0.sh ];
then
  wget -P $SRC $URL_UBOOT
  chmod +x $SRC/install_uboot_mtd0.sh
fi

echo "Installing Bootloader"
# install uBoot on mtd0
$SRC/install_uboot_mtd0.sh --noprompt


##########
##########
#
# Format /dev/sda
#
##########
##########

umount $ROOT > /dev/null 2>&1

if [ ! -f $SRC/mke2fs ];
then
  wget -P $SRC $URL_MKE2FS
  chmod +x $SRC/mke2fs
fi

$SRC/mke2fs $ROOT_DEV
/sbin/mkswap $SWAP_DEV

mount $ROOT_DEV $ROOT



                                                          

##########
##########
#
# Download Packages
#
##########
##########

echo ""
echo ""
echo ""
echo "Downloading packages to $SRC"
echo ""
echo "Downloading Debian base"

if [ ! -f $SRC/base.tar.bz2 ];
then
  wget -P $SRC $URL_DEBIAN_BASE
fi


echo ""
echo "Downloading sheeva kernel"

# Get sheeva kernel
if [ ! -f $SRC/sheeva-2.6.33-uImage ];
then
  wget -P $SRC $URL_SHEEVA_UIMAGE
fi

# Get sheeva modules
if [ ! -f $SRC/sheeva-2.6.33-Modules.tar.gz ];
then
  wget -P $SRC $URL_SHEEVA_MODULES
fi



##########
##########
#
#
# Install Packages
#
#
##########
##########


# Extract Debian base
tar -xjv -C $ROOT -f $SRC/base.tar.bz2

# Remove old debian boot and modules
rm -rf $ROOT/boot
rm -rf $ROOT/lib/modules
mkdir $ROOT/boot

## Generate /etc/fstab
echo \
"# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
none           /dev/pts        devpts  defaults          0       0
none           /dev/shm        tmpfs   nodev,nosuid      0       0
$ROOT_DEV      /               ext2    noatime,errors=remount-ro 0       1
$SWAP_DEV      none            swap    sw                0       0
" > $ROOT/etc/fstab

#proc           /proc           proc    defaults          0       0

cp $SRC/sheeva-2.6.33-uImage $ROOT/boot/uImage
chmod 644 $ROOT/boot/uImage
tar -xzv -C $ROOT -f $SRC/sheeva-2.6.33-Modules.tar.gz


##### All Done

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

