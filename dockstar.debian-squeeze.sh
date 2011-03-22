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


# Version 1.0   [8/8/2010] Initial Release


# Definitions

# Download locations
MIRROR="http://jeff.doozan.com/debian"

DEB_MIRROR="http://cdn.debian.net/debian"

MKE2FS_URL="$MIRROR/mke2fs"
PKGDETAILS_URL="$MIRROR/pkgdetails"
URL_UBOOT="$MIRROR/uboot/install_uboot_mtd0.sh"
URL_DEBOOTSTRAP="$DEB_MIRROR/pool/main/d/debootstrap/debootstrap_1.0.28_all.deb"
URL_FW_CONFIG="$MIRROR/uboot/fw_env.config"

# Default binary locations
MKE2FS=/sbin/mke2fs
PKGDETAILS=/usr/share/debootstrap/pkgdetails

# Where should the temporary 'debian root' be mounted
ROOT=/tmp/debian

# debootstrap configuration
RELEASE=squeeze
VARIANT=minbase

# if you want to install additional packages, add them to the end of this list
EXTRA_PACKAGES=linux-image-2.6-kirkwood,flash-kernel,module-init-tools,udev,netbase,ifupdown,iproute,openssh-server,dhcpcd,iputils-ping,wget,net-tools,ntpdate,uboot-mkimage,uboot-envtools,vim-tiny
KERNEL_VERSION=2.6.32-5-kirkwood









#########################################################
#  There are no user-serviceable parts below this line
#########################################################

RO_ROOT_=0

TIMESTAMP=$(date +"%d%m%Y%H%M%S")
touch /sbin/$TIMESTAMP
if [ ! -f /sbin/$TIMESTAMP ]; then
  RO_ROOT=1
else
  rm /sbin/$TIMESTAMP
fi

verify_md5 ()
{
  local file=$1
  local md5=$2

  local check_md5=$(cat "$md5" | cut -d' ' -f1) 
  local file_md5=$(md5sum "$file" | cut -d' ' -f1)  

  if [ "$check_md5" = "$file_md5" ]; then
    return 0
  else
    return 1
  fi
}

download_and_verify ()
{
  local file_dest=$1
  local file_url=$2

  local md5_dest="$file_dest.md5"
  local md5_url="$file_url.md5"

  # Always download a fresh MD5, in case a newer version is available
  if [ -f "$md5_dest" ]; then rm -f "$md5_dest"; fi
  wget -O "$md5_dest" "$md5_url"
  # retry the download if it failed
  if [ ! -f "$md5_dest" ]; then
    wget -O "$md5_dest" "$md5_url"
    if [ ! -f "$md5_dest" ]; then
      return 1 # Could not get md5
    fi
  fi

  # If the file already exists, check the MD5
  if [ -f "$file_dest" ]; then
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then
      rm -f "$md5_dest"
      return 0
    else
      rm -f "$file_dest"
    fi
 fi

  # Download the file
  wget -O "$file_dest" "$file_url"
  # retry the download if it failed
  verify_md5 "$file_dest" "$md5_dest"
  if [ "$?" -ne "0" ]; then  
    # Download failed or MD5 did not match, try again
    if [ -f "$file_dest" ]; then rm -f "$file_dest"; fi
    wget -O "$file_dest" "$file_url"
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then  
      rm -f "$md5_dest"
      return 1
    fi
  fi

  rm -f "$md5_dest"
  return 0
}

install ()
{
  local file_dest=$1
  local file_url=$2   
  local file_pmask=$3  # Permissions mask
  
  echo "# checking for $file_dest..."

  # Install target file if it doesn't already exist
  if [ ! -s "$file_dest" ]; then
    echo ""
    echo "# Installing $file_dest..."

    # Check for read-only filesystem by testing
    #  if we can delete the existing 0 byte file
    #  or, if we can create a 0 byte file
    local is_readonly=0
    if [ -f "$file_dest" ]; then
      rm -f "$file_dest" 2> /dev/null
    else
      touch "$file_dest" 2> /dev/null
    fi
    if [ "$?" -ne "0" ]; then
      local is_readonly=0
      mount -o remount,rw /
    fi
    rm -f "$file_dest" 2> /dev/null
        
    download_and_verify "$file_dest" "$file_url"
    if [ "$?" -ne "0" ]; then
      echo "## Could not install $file_dest from $file_url, exiting."
      if [ "$is_readonly" = "1" ]; then
        mount -o remount,ro /
      fi
      exit 1
    fi

    chmod $file_pmask "$file_dest"

    if [ "$is_readonly" = "1" ]; then
      mount -o remount,ro /
    fi

    echo "# Successfully installed $file_dest."
  fi

  return 0
}



if ! which chroot >/dev/null; then
  echo ""
  echo ""
  echo ""
  echo "ERROR. CANNOT CONTINUE."
  echo ""
  echo "Cannot find chroot.  You need to update your PATH."
  echo "Run the following command and then run this script again:"
  echo ""
  echo 'export PATH=$PATH:/sbin:/usr/sbin'
  echo ""
  exit 1
fi

echo ""
echo ""
echo "!!!!!!  DANGER DANGER DANGER DANGER DANGER DANGER  !!!!!!"
echo ""
echo "This script will replace the bootloader on /dev/mtd0."
echo ""
echo "If you lose power while the bootloader is being flashed,"
echo "your device could be left in an unusable state."
echo ""
echo ""
echo "This script will configure your Dockstar to boot Debian Squeeze"
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
SRC=$ROOT


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

umount $ROOT > /dev/null 2>&1

if ! which mke2fs >/dev/null; then
  install "$MKE2FS"         "$MKE2FS_URL"          755
else
  MKE2FS=$(which mke2fs)
fi

$MKE2FS $ROOT_DEV
/sbin/mkswap $SWAP_DEV

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

  if [ "$RO_ROOT" = "1" ]; then
    mount -o remount,rw /
  fi
  mv ./usr/sbin/debootstrap /usr/sbin
  mv ./usr/share/debootstrap /usr/share

  install "$PKGDETAILS" "$PKGDETAILS_URL" 755

  if [ "$RO_ROOT" = "1" ]; then
    mount -o remount,ro /
  fi
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

# Squeeze
/usr/sbin/debootstrap --verbose --arch=armel --variant=$VARIANT --include=$EXTRA_PACKAGES $RELEASE $ROOT $DEB_MIRROR

if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See $ROOT/debootstrap/debootstrap.log for more information."
  exit 1
fi


cat <<END > $ROOT/etc/apt/apt.conf
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END

chroot /tmp/debian /usr/bin/mkimage -A arm -O linux -T kernel  -C none -a 0x00008000 -e 0x00008000 -n Linux-$KERNEL_VERSION -d /boot/vmlinuz-$KERNEL_VERSION /boot/uImage
chroot /tmp/debian /usr/bin/mkimage -A arm -O linux -T ramdisk -C gzip -a 0x00000000 -e 0x00000000 -n initramfs-$KERNEL_VERSION -d /boot/initrd.img-$KERNEL_VERSION /boot/uInitrd


echo debian > $ROOT/etc/hostname
echo LANG=C > $ROOT/etc/default/locale

cat <<END > $ROOT/etc/fw_env.config
# MTD device name	Device offset	Env. size	Flash sector size	Number of sectors
/dev/mtd0 0xc0000 0x20000 0x20000
END

cat <<END > $ROOT/etc/network/interfaces
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
END

cat <<END > $ROOT/etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root      /               ext2    noatime,errors=remount-ro 0 1
$SWAP_DEV      none            swap    sw                0       0
tmpfs          /tmp            tmpfs   defaults          0       0
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

echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux' >> $ROOT/etc/inittab
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' $ROOT/etc/inittab

echo HWCLOCKACCESS=no >> $ROOT/etc/default/rcS
echo CONCURRENCY=shell >> $ROOT/etc/default/rcS

if [ -e $ROOT/etc/blkid.tab ]; then
  rm $ROOT/etc/blkid.tab
fi
ln -s /dev/null $ROOT/etc/blkid.tab

if [ -e $ROOT/etc/mtab ]; then
  rm $ROOT/etc/mtab
fi
ln -s /proc/mounts $ROOT/etc/mtab

echo "root:\$1\$XPo5vyFS\$iJPfS62vFNO09QUIUknpm.:14360:0:99999:7:::" > $ROOT/etc/shadow




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
echo "The new root password is 'root'  Please change it immediately after"
echo "logging in."
echo ""
echo -n "Reboot now? [Y/n] "

read IN
if [ "$IN" = "" -o "$IN" = "y" -o "$IN" = "Y" ];
then
  /sbin/reboot
fi

