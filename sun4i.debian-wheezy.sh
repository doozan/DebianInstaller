#!/bin/sh
#
# Install Debian Wheezy on Kirkwood devices

# Copyright (c) 2012 Jeff Doozan
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


# Version 1.3    [8/29/2012] Add mali x11 support
# Version 1.2    [7/27/2012] Support for custom installs via debian-installer.config
#                            Install a simple GUI
# Version 1.1    [7/26/2012] Remove dockstar specific cruft
#                            Use system.bin to populate /etc/modules
#                            Add --noprompt and --extra-packages options
# Version 1.0    [7/24/2012] Initial Release


# Definitions


DEBIAN_INSTALLER=1.3

# Download locations
MIRROR="http://download.doozan.com"

DEB_MIRROR="http://cdn.debian.net/debian"

PKGDETAILS=/usr/share/debootstrap/pkgdetails
PKGDETAILS_URL="$MIRROR/debian/pkgdetails"

A10_DISPLAY=/sbin/a10_display
A10_DISPLAY_URL=$MIRROR/a10/a10_display

DEBOOTSTRAP_VERSION=$(wget -q "$DEB_MIRROR/pool/main/d/debootstrap/?C=M;O=D" -O- | grep -o 'debootstrap[^"]*all.deb' | head -n1)
DEBOOTSTRAP_URL="$DEB_MIRROR/pool/main/d/debootstrap/$DEBOOTSTRAP_VERSION"

# Where should the temporary 'debian root' be mounted
ROOT=/tmp/debian

# debootstrap configuration
RELEASE=wheezy
VARIANT=minbase
ARCH=armhf
COMPONENTS=main,non-free

# if you want to install additional packages, add them to the end of this list
BASE_PACKAGES=module-init-tools,udev,netbase,ifupdown,iproute,openssh-server,dhcpcd,iputils-ping,wget,net-tools,ntpdate,uboot-mkimage,vim-tiny,dialog,busybox-static,initramfs-tools,less,ca-certificates,wpasupplicant,firmware-realtek,wireless-tools

# Install mini GUI by default
INSTALL_MINI_GUI=1
MINI_GUI_PACKAGES=xserver-xorg,xserver-xorg-input-all,xserver-xorg-video-fbdev,xserver-xorg-core,xinit,fluxbox,xterm
MALI_GL_URL="http://dl.dropbox.com/u/65312725/mali_opengl_hf_lib.tgz"
MALI_URL="$MIRROR/a10/xfree86-video-mali-r2p4-02rel1.tgz"


KERNEL_URL="$MIRROR/debian/linux-image-wheezy-sun4i.deb"

ROOT_DEV=/dev/mmcblk0p2
SWAP_DEV=/dev/mmcblk0p3




#########################################################
#  There are no user-serviceable parts below this line
#########################################################

RO_ROOT=0

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

if [ -x /usr/bin/perl ]; then
  if [ "`/usr/bin/perl -le 'print $ENV{PATH}`" == "" ]; then
    echo ""
    echo "Your perl subsystem does not have support for \$ENV{}"
    echo "and must be disabled for debootstrap to work"
    echo "Please disable perl by running the following command"
    echo ""
    echo "chmod -x /usr/bin/perl"
    echo ""
    echo "After perl is disabled, you can re-run this script."
    echo "To re-enable perl after installation, run:"
    echo ""
    echo "chmod +x /usr/bin/perl"
    echo ""
    echo "Installation aborted."
    exit
  fi
fi

# Parse command line
for i in $*
do
  case $i in
    --extra-packages=*)
      CLI_PACKAGES=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      ;;
    --noprompt)
      NOPROMPT=1
      ;;
    *)
      ;;
  esac
done


# Source config file
# Config file must be in the same directory as this installer
# and must match the naming pattern debian-installer*.config

config_postinstall()
{
  true
  # This is a placeholder routine
}

shopt -s nullglob

DIR="$( cd "$( dirname "$0" )" && pwd )"
CONFIG=

for file in $DIR/debian-installer*.config ; do
  if [ $CONFIG ]; then
    echo "Config file $file conflicts with $CONFIG.  Only one config file can be used."
    exit 1
  fi
  CONFIG=$file
done

if [ -f "$CONFIG" ]; then
  echo "Reading $CONFIG"
  . $CONFIG
fi
shopt -u nullglob

PACKAGES=$BASE_PACKAGES
if [ $INSTALL_MINI_GUI ]; then
  PACKAGES=$PACKAGES,$MINI_GUI_PACKAGES
fi
if [ "$CLI_PACKAGES" != "" ]; then
  PACKAGES=$PACKAGES,$CLI_PACKAGES
fi
if [ "$CONFIG_PACKAGES" != "" ]; then
  PACKAGES=$PACKAGES,$CONFIG_PACKAGES
fi

if [ "$NOPROMPT" != "1" ]; then
  echo ""
  echo ""
  echo "This script will configure your A10 Device to boot Debian"
  echo "from $ROOT_DEV.  Before running this script, you should have"
  echo "used fdisk to create the following partitions:"
  echo ""
  echo "$ROOT_DEV (Linux ext, at least 400MB)"
  echo "$SWAP_DEV (Linux swap, recommended 256MB)"
  echo ""
  echo ""
  echo "This script will DESTROY ALL EXISTING DATA on $ROOT_DEV and $SWAP_DEV"
  echo "Please double check that the device on $ROOT_DEV is the correct device."
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
fi


# Create the mount point if it doesn't already exist
if [ ! -f $ROOT ];
then
  mkdir -p $ROOT
fi


##########
##########
#
# Format rootfs
#
##########
##########

umount $ROOT > /dev/null 2>&1

mke2fs $ROOT_DEV
mkswap $SWAP_DEV

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
  wget -O debootstrap.deb $DEBOOTSTRAP_URL
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

/usr/sbin/debootstrap --verbose --no-check-certificate --arch=$ARCH --variant=$VARIANT --components=$COMPONENTS --include=$PACKAGES $RELEASE $ROOT $DEB_MIRROR

if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See $ROOT/debootstrap/debootstrap.log for more information."
  exit 1
fi


echo debian > $ROOT/etc/hostname
echo LANG=C > $ROOT/etc/default/locale

cat <<END > $ROOT/etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
$ROOT_DEV      /               ext3    noatime,errors=remount-ro 0 1
$SWAP_DEV      none            swap    sw                0       0
tmpfs          /tmp            tmpfs   defaults          0       0
END


# Disable tty until fbconsole works
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' $ROOT/etc/inittab
echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux' >> $ROOT/etc/inittab

if [ $INSTALL_MINI_GUI ]; then

  # Install mali drivers
  wget -O $ROOT/tmp/mali.tgz $MALI_URL
  tar -xzvf $ROOT/tmp/mali.tgz -directory $ROOT/usr/lib/xorg/modules/drivers
  rm $ROOT/tmp/mali.tgz

  wget -O $ROOT/tmp/mali_gl.tgz $MALI_GL_URL
  tar -xzvf $ROOT/tmp/mali_gl.tgz --directory $ROOT/tmp
  mv $ROOT/tmp/mali_opengl_hf_lib/* $ROOT/usr/lib
  rmdir $ROOT/tmp/mali_opengl_hf_lib
  rm $ROOT/tmp/mali_gl.tgz

  # Run x as root on tty6 
  echo "6:23:respawn:/bin/login -f root tty6 </dev/tty6 >/dev/tty6 2>&1" >>  $ROOT/etc/inittab

  # Add module loading fix to rc.local
  # ump does not load well unless hdmi has been loaded first (even though hdmi is compiled into the kernel)
  sed -i 's/^exit 0/modprobe hdmi ump\nexit 0/' $ROOT/etc/rc.local

  # Configure .profile to run startx
  cat<<EOF | cat - $ROOT/root/.profile > $ROOT/root/.profile.tmp
if [ -z "\$DISPLAY" ] && [ \$(tty) == /dev/tty6 ]; then
    startx
    exit 0
fi
EOF
  cat $ROOT/root/.profile.tmp > $ROOT/root/.profile
  rm $ROOT/root/.profile.tmp

  cat<<EOF>/$ROOT/etc/X11/xorg.conf
# X.Org X server configuration file for xfree86-video-mali

Section "Device"
        Identifier "Mali FBDEV"
        Driver  "mali"
        Option  "fbdev"            "/dev/fb0"
        Option  "DRI2"             "false"
        Option  "DRI2_PAGE_FLIP"   "false"
        Option  "DRI2_WAIT_VSYNC"  "false"
EndSection

Section "Screen"
        Identifier      "Mali Screen"
        Device          "Mali FBDEV"
        DefaultDepth    24
EndSection

Section "DRI"
        Mode 0666
EndSection
EOF

fi

echo HWCLOCKACCESS=yes >> $ROOT/etc/default/rcS
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


# The update-initramfs needs to be able to find the device associated with the rootfs
# and busybox is unable to mount --bind /dev into the chroot.  As such, we need
# to explicitly create a few device nodes before installing the kernel

mknod $ROOT/dev/mmcblk0 b 179 0
mknod $ROOT/dev/mmcblk0p1 b 179 1
mknod $ROOT/dev/mmcblk0p2 b 179 2
mknod $ROOT/dev/mmcblk0p3 b 179 3

# Install the kernel
wget -O $ROOT/tmp/kernel.deb $KERNEL_URL
KERNEL_VERSION=`chroot $ROOT /usr/bin/dpkg-deb -I /tmp/kernel.deb | grep "Package: linux-image" | cut -d "-" -f 3-4`
chroot $ROOT /usr/bin/dpkg -i /tmp/kernel.deb
rm $ROOT/tmp/kernel.deb

chroot $ROOT /usr/bin/mkimage -A arm -O linux -T kernel  -C none -a 0x40008000 -e 0x40008000 -n Linux-$KERNEL_VERSION -d /boot/vmlinuz-$KERNEL_VERSION /boot/uImage
chroot $ROOT /usr/bin/mkimage -A arm -O linux -T ramdisk -C gzip -a 0x00000000 -e 0x00000000 -n initramfs-$KERNEL_VERSION -d /boot/initrd.img-$KERNEL_VERSION /boot/uInitrd


# Install the display control utility
install "$ROOT/$A10_DISPLAY" "$A10_DISPLAY_URL" 755

# Enable wifi module
echo 8192cu >> $ROOT/etc/modules

# If script.bin has emac enabled, load the wemac module
WIRED=`fexc -I bin -O fex /mnt/sysconfig/system.bin | grep emac_used | cut -d " " -f 3`
if [ $WIRED ]; then
  echo sun4i_wemac >> $ROOT/etc/modules
fi

# Copy network configuration from sysconfig partition
if [ -f /mnt/sysconfig/rescue/interfaces ]; then
  cp /mnt/sysconfig/rescue/interfaces $ROOT/etc/network/
  chmod 644 $ROOT/etc/network/interfaces
fi
if [ -f /mnt/sysconfig/rescue/wpa_supplicant.conf ]; then
  cp /mnt/sysconfig/rescue/wpa_supplicant.conf $ROOT/etc/
  chmod 600 $ROOT/etc/wpa_supplicant.conf
fi

# Call config_postinstall to do any custom configuration
config_postinstall


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

if [ "$NOPROMPT" != "1" ]; then
  echo -n "Reboot now? [Y/n] "

  read IN
  if [ "$IN" = "" -o "$IN" = "y" -o "$IN" = "Y" ];
  then
    /sbin/reboot
  fi
fi

