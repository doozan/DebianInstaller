# Unlocking your Dockstar, GoFlex, or Pogoplug

This guide will replace the locked [bootloader](http://forum.doozan.com/uboot/) on your device with a new version that can boot from a variety of locations,
including USB drives.  
The installer will create a simple [Debian](http://debian.org) Linux installation on your external USB drive.  
From there, you can install any of the [25,000+ packages](http://packages.debian.org/wheezy/) from the Debian repository.  
If you decide that you don't like Debian and want to use the old Pogoplug software, simply unplug your USB drive and reboot.

After you've installed Debian, please visit the [forums](http://forum.doozan.com) for additional project ideas and support.

If you'd prefer to run a distro other than Debian, and just want to unlock the bootloader, please see the [uBoot](http://forum.doozan.com/uboot/) page.

## Install Debian Linux

This will install Debian on a USB drive connected to your Dockstar.  
If you wish to install Debian Lenny, please see the <a href="install_lenny.htm">old installation</a> page.  
If you would like to install Debian to the internal flash memory instead of a USB drive,
please see [this discussion](http://forum.doozan.com/read.php?2,72) on the forum.

Find your devices's IP address and connect via SSH:
```
username: root
password: (the password is 'stxadmin' on Seagate branded devices and 'ceadmin' on Pogoplug devices)
```

Partition your flash drive with [fdisk](http://tldp.org/HOWTO/Partition/fdisk_partitioning.html):
```
fdisk /dev/sda
# Configure partion 1 as Linux (I'd recommend making this at least 512Mb. The default bare-bones installation uses 280Mb.)
# Configure partion 2 as Linux Swap (I used 256MB.  Adjust according to your anticipated memory usage.)
# Set partition 1 active
```


Download and run the Debian Wheezy installer:
```
cd /tmp
wget http://projects.doozan.com/debian/kirkwood.debian-wheezy.sh
chmod +x kirkwood.debian-wheezy.sh
export PATH=$PATH:/usr/sbin:/sbin
./kirkwood.debian-wheezy.sh
```

Alternatively, you can choose to install Debian Squeeze with the following commands:
```
cd /tmp
wget http://projects.doozan.com/debian/dockstar.debian-squeeze.sh
chmod +x dockstar.debian-squeeze.sh
export PATH=$PATH:/usr/sbin:/sbin
./dockstar.debian-squeeze.sh
```

The script will take some time to download the debian images and extract them to your flash drive.  
The total install time will vary with the speed of your flash drive and your Internet connection.  
On my system, it takes about 20 minutes.  
Once it's finished, you can reboot into your new Debian install.

After your device reboots, it may have a different IP address (it's identifying as 'Debian' to the DHCP server now instead of 'Pogoplug').

The default root password in Debian is `root`.  
After you've logged in, you should change the root password and configure `/etc/apt/sources.list` to point to a [Debian mirror](http://www.debian.org/mirror/list) near you.

```
passwd
vi /etc/apt/sources.list
```

## <a name="troubleshooting"></a>Troubleshooting

Most boot problems are caused by bad USB drives.  
In general, flash drives boot more reliably than hard drives.

If you're having trouble, it's usually wise to try using a different flash drive.

For more information on user-tested drives, see this [discussion](http://forum.doozan.com/read.php?2,1915) in the forum.

Many problems can be diagnosed by looking at the uBoot console.  
If you don't have a serial connection to your device,
you can still view the console by configuring [netconsole](http://forum.doozan.com/read.php?3,14,14).

## Forum
For any questions and discussion of Debian on the Dockstar, please visit the [forum](http://forum.doozan.com/).

Enjoy,

-- Jeff
