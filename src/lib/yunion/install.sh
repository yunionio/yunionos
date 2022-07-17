#!/bin/sh

ROLE=$1

if [ "$ROLE" != "controller" ] && [ "$ROLE" != "host" ]; then
  echo "Usage: $0 <controller|host>"
  exit 1
fi


. /lib/yunion/functions


CONFIGPROC="yes"

while [ "$CONFIGPROC" == "yes" ]
do
#############################################################

echo "Prepare disk ..."

RAID=$(detect_raid)
echo "Disk raid driver $RAID"
if [ "$RAID" == "Linux" ]; then
  DISK=$(/lib/mos/lsdisk --scsi | head -n 1 | awk '{print $1}')
  if [ -z "$DISK" ]; then
    echo "No valid disk found, exiting..."
    exit 1
  fi
  echo "No RAID controller found, going to use disk $DISK ..."
else
  echo "RAID controller $RAID detected, please specify RAID level:"
  echo "[RAID0] RAID0 - No redundancy"
  echo "[RAID10] RAID1 or RAID10 - 100% redundancy"
  echo "[RIAD5] RAID5 - 1/N redundancy, where N is the number of disks"
  RAIDCONF=
  while [ -z $RAIDCONF ]; do
    echo -n "Please input RAID0, RAID10 or RAID5 (default is [RAID10], i.e. RAID1 or RAID10): "
    read RAIDCONF
    if [ -z $RAIDCONF ]; then
      RAIDCONF="RAID10"
    fi
    if [ "$RAIDCONF" != "RAID0" ] && [ "$RAIDCONF" != "RAID10" ] && [ "$RAIDCONF" != "RAID5" ]; then
      echo "Invalid RAID level: $RAIDCONF"
      RAIDCONF=
    fi
  done
fi


echo "Prepare network ..."
NIC_CNT=$(/lib/mos/lsnic up | wc -l)
if [ "$NIC_CNT" -eq "0" ]; then
  echo "No active nic found"
  exit 1
fi

BONDING=

if [ "$NIC_CNT" -gt "1" ]; then
  echo -n "More than 1 NICs are up, do binding? (yes or no): "
  read do_binding
  if [ "$do_binding" == "yes" ]; then
    BONDING="yes"
    ALLNIC=$(/lib/mos/lsnic -n up | awk '{print $1}' | xargs)
    NIC=
    while [ -z $NIC ]; do
      echo "Please input all interfaces to be included in bond ($ALLNIC):"
      read TMPNIC
      for n in $TMPNIC
      do
        if [ ! -d /sys/class/net/$n ]; then
          echo "$n is not a NIC"
        else
          NIC="$NIC $n"
        fi
      done
      NIC_CNT=$(echo "$NIC" | awk '{print NF}')
      if [ "$NIC_CNT" -lt 2 ]; then
        echo "Binding needs at least two slave interfaces"
        NIC=
      fi
    done
  else
    ALLNIC=$(/lib/mos/lsnic -n up | awk '{print $1}' | xargs)
    echo -n "Input interface name to be activate ($ALLNIC): "
    NIC=
    while [ -z "$NIC" ]; do
      read NIC
      if [ ! -d /sys/class/net/$NIC ]; then
        echo "$NIC is not a valid interface name"
        NIC=
      fi
    done
  fi
else
  NIC=$(/lib/mos/lsnic -n up | head -n 1 | awk '{print $1}')
fi

IP=
while [ -z "$IP" ]; do
  echo -n "IP address: "
  read IP
done

DEFAULT_MASK=255.255.255.0
echo -n "Netmask (default is $DEFAULT_MASK): "
read MASK
if [ -z "$MASK" ]; then
  MASK=$DEFAULT_MASK
fi

GATEWAY=
while [ -z "$GATEWAY" ]; do
  echo -n "Default gateway: "
  read GATEWAY
done

DNS=
while [ -z "$DNS" ]; do
  echo -n "DNS server: "
  read DNS
done

DOMAIN=
while [ -z "$DOMAIN" ]; do
  echo -n "DNS domain: "
  read DOMAIN
done

if [ "$ROLE" == "controller" ]; then
  DEFAULT_HOSTNAME="yunionctrler"
elif [ "$ROLE" == "host" ]; then
  DEFAULT_HOSTNAME="yunionhost"
fi
echo -n "Hostname (default is $DEFAULT_HOSTNAME): "
read HOSTNAME
if [ -z "$HOSTNAME" ]; then
  HOSTNAME=$DEFAULT_HOSTNAME
fi

DEFAULT_REGION="Yunion"
echo -n "Region for cloud (default is $DEFAULT_REGION): "
read REGION
if [ -z "$REGION" ]; then
  REGION=$DEFAULT_REGION
fi

if [ "$ROLE" == "controller" ]; then

  DEFAULT_ZONE="zone1"
  echo -n "The name of first zone (default is $DEFAULT_ZONE): "
  read ZONE
  if [ -z "$ZONE" ]; then
    ZONE=$DEFAULT_ZONE
  fi

  DEFAULT_CLOUD_DOMAIN=$DOMAIN
  echo -n "The domain for cloud servers (default is $DEFAULT_CLOUD_DOMAIN): "
  read CLOUD_DOMAIN
  if [ -z "$CLOUD_DOMAIN" ]; then
    CLOUD_DOMAIN=$DEFAULT_CLOUD_DOMAIN
  fi

elif [ "$ROLE" == "host" ]; then

  AUTHURI=
  while [ -z "$AUTHURI" ]; do
    echo -n "Keystone Auth URI: "
    read AUTHURI
  done

  HOSTADMIN=
  while [ -z "$HOSTADMIN" ]; do
    echo -n "Host admin account: "
    read HOSTADMIN
  done

  HOSTPASS=
  while [ -z "$HOSTPASS" ]; do
    echo -n "Host admin password: "
    read HOSTPASS
  done

  DEFAULT_HOSTPROJECT=system
  echo -n "Host project (default is $DEFAULT_HOSTPROJECT): "
  read HOSTPROJECT
  if [ -z "$HOSTPROJECT" ]; then
    HOSTPROJECT=$DEFAULT_HOSTPROJECT
  fi

fi

DEFAULT_ROOT_PASS=$(genpasswd)
echo -n "Password for yunion login account (default is $DEFAULT_ROOT_PASS): "
read ROOT_PASS
if [ -z "$ROOT_PASS" ]; then
  ROOT_PASS=$DEFAULT_ROOT_PASS
fi

if [ "$ROLE" == "controller" ]; then

  DEFAULT_DB_PASS=$(genpasswd)
  echo -n "Password for mariadb (default is $DEFAULT_DB_PASS): "
  read DB_PASS
  if [ -z "$DB_PASS" ]; then
    DB_PASS=$DEFAULT_DB_PASS
  fi

  DEFAULT_SYSADMIN_PASS=$(genpasswd)
  echo -n "Password for cloud sysadmin (default is $DEFAULT_SYSADMIN_PASS): "
  read SYSADMIN_PASS
  if [ -z "$SYSADMIN_PASS" ]; then
    SYSADMIN_PASS=$DEFAULT_SYSADMIN_PASS
  fi

fi

echo ""
echo "############## Summary ########################"

echo "Storage settings:"
if [ "$RAID" == "Linux" ]; then
  echo "  Disk to install: $DISK"
else
  echo "  Raid driver: $RAID Raid level: $RAIDCONF"
fi

echo ""

echo "Network settings:"
echo "  Interface: $NIC"
if [ -n "$BONDING" ]; then
  echo "  Bonding: yes"
fi
echo "  IP: $IP"
echo "  Netmask: $MASK"
echo "  Geteway: $GATEWAY"
echo "  DNS: $DNS"
echo "  Domain: $DOMAIN"

echo ""

echo "Account settings:"
echo "  OS login account: yunion"
echo "  Password for yunion: $ROOT_PASS"

if [ "$ROLE" == "controller" ]; then

  echo "  DB root password: $DB_PASS"
  echo "  Cloud admin account: sysadmin"
  echo "  Password for sysadmin: $SYSADMIN_PASS"

  echo ""

  echo "Cloud settings:"
  echo "  Region: $REGION"
  echo "  Zone: $ZONE"
  echo "  Hostname: $HOSTNAME"
  echo "  Domain for cloud servers: $CLOUD_DOMAIN"

elif [ "$ROLE" == "host" ]; then

  echo ""

  echo "Yunion Cloud settings:"
  echo "  Region: $REGION"
  echo "  Keystone AuthURI: $AUTHURI"
  echo "  Host admin account: $HOSTADMIN"
  echo "  Host admin password: $HOSTPASS"
  echo "  Host admin project: $HOSTPROJECT"
  echo "  Hostname: $HOSTNAME"

fi

echo "###############################################"
PROCEED=
while [ -z "$PROCEED" ]; do
  echo -n "Proceed to installation? (yes, no or reboot): "
  read PROCEED

  if [ "$PROCEED" == "reboot" ]; then
    reboot
    exit 1
  elif [ "$PROCEED" == "no" ]; then
    CONFIGPROC=yes
    echo "Redo configuration ..."
    echo ""
  elif [ "$PROCEED" == "yes" ]; then
    CONFIGPROC=no
    echo "Do installation ..."
    echo ""
  else
    PROCEED=
  fi
done

##########################################################
done


if [ "$RAID" != "Linux" ]; then
  echo "Going to configure $RAID disks with ${RAIDCONF} ..."
  if ! build_raid $RAID $RAIDCONF; then
     echo "Build raid failed, exiting ..."
     exit 1
  fi
  MAX_TRIES=60
  TRIED=0
  while [ "$TRIED" -lt "$MAX_TRIES" ] && [ ! -d /sys/class/block/sda ]
  do
    TRIED=$((TRIED+1))
    sleep 1
  done
  if [ ! -d /sys/class/block/sda ]; then
    echo "No disk found, raid build failed???"
    exit 1
  else
    DISK=sda
  fi
fi


echo "Mounting installation medium ..."

CDROM=

for dev in $(/lib/mos/lsdisk --removable | awk '{print $1}')
do
    echo "Try mouting /dev/$dev ..."
    mount /dev/$dev /mnt
    if [ "$?" -eq "0" ]; then
        if [ -d /mnt/images ]; then
            CDROM=$dev
            break
        else
            umount /mnt
        fi
    fi
done

if [ -z "$CDROM" ]; then
    echo "No installation medium found, exiting ..."
    exit 1
fi

IMAGE=$(ls /mnt/images | tail -n 1)

if [ -z "$IMAGE" ]; then
  echo "No image found"
  exit 1
fi

IMAGE="/mnt/images/$IMAGE"

echo "Going to install image $IMAGE to $DISK ..."

/lib/mos/copyimage.sh $IMAGE $DISK

if [ "$?" -ne "0" ]; then
  echo "Fail to copy rootfs, exit ..."
  exit 1
fi

LASTSEC=$(sgdisk /dev/$DISK --print | grep "last usable sector is " | awk '{print $NF}')
ENDIDX=$(sgdisk /dev/$DISK --print | tail -n 1 | awk '{print $1}')
ENDSEC=$(sgdisk /dev/$DISK --print | tail -n 1 | awk '{print $3}')

STARTSEC=$((ENDSEC>>11))
STARTSEC=$((STARTSEC+1))
STARTSEC=$((STARTSEC<<11))

DATAIDX=$((ENDIDX+1))
ENDSEC=$((LASTSEC>>11<<11))
ENDSEC=$((ENDSEC-1))

echo "Create data disk $DISK$DATAIDX $STARTSEC:$ENDSEC ..."

sgdisk /dev/$DISK --new=$DATAIDX:$STARTSEC:$ENDSEC

mkfs.ext4 /dev/${DISK}${DATAIDX}

echo "Mount root disk ..."

ROOTFS=/tmp/rootfs
mkdir -p $ROOTFS
mount /dev/${DISK}${ENDIDX} $ROOTFS

echo "OS configuration ..."

echo "fstab configuration ..."

DEVNAME="/dev/${DISK}${DATAIDX}"
UUID=$(blkid $DEVNAME)
UUID=${UUID:$((${#DEVNAME}+8)):36}
echo "UUID=${UUID}    /opt/cloud/workspace    ext4    defaults    1   1" >> $ROOTFS/etc/fstab

echo "Network configuration ..."

echo "127.0.0.1 localhost
$IP $HOSTNAME.$DOMAIN $HOSTNAME" > $ROOTFS/etc/hosts

echo "NETWORKING=yes
HOSTNAME=$HOSTNAME.$DOMAIN" > $ROOTFS/etc/sysconfig/network

echo "$HOSTNAME" > $ROOTFS/etc/hostname

for f in $(ls $ROOTFS/etc/udev/rules.d/*.rules)
do
  echo "" > $f
done

for n in $(/lib/mos/lsnic -n | awk '{print $1}')
do
  MAC=$(cat /sys/class/net/$n/address)
  echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$MAC\", NAME=\"$n\"" >> $ROOTFS/etc/udev/rules.d/70-persistent-net.rules
done

if [ "$BONDING" == "yes" ]; then
  BNIC="bond0"
  echo "alias $BNIC bonding
options $BNIC miimon=100 mode=2 xmit_hash_policy=1" > $ROOTFS/etc/modprobe.d/bonding.conf
  for n in $NIC
  do
    echo "DEVICE=$n
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
MASTER=$BNIC
SLAVE=yes" > $ROOTFS/etc/sysconfig/network-scripts/ifcfg-$n
  done
  NIC=$BNIC
fi

echo "DEVICE=$NIC
ONBOOT=yes
BOOTPROTO=none
NETMASK=$MASK
IPADDR=$IP
USERCTL=no
GATEWAY=$GATEWAY
PEERDNS=yes
DNS1=$DNS
DOMAIN=$DOMAIN" > $ROOTFS/etc/sysconfig/network-scripts/ifcfg-$NIC

echo "Configure password ..."

chroot $ROOTFS passwd yunion << EOF
$ROOT_PASS
$ROOT_PASS
EOF

echo "Copy packages ..."

CLOUDPKG=$(ls /mnt/cloud | tail -n 1)

if [ -n "$CLOUDPKG" ]; then
  echo "Extract $CLOUDPKG ..."
  gunzip -c /mnt/cloud/$CLOUDPKG | tar xf - -C $ROOTFS/opt/
fi

if [ "$ROLE" == "controller" ]; then

  DISTPKG=$(ls /mnt/dist | tail -n 1)

  if [ -n "$DISTPKG" ]; then
    YUNIONWEB=/opt/$DISTPKG
    cp /mnt/dist/$DISTPKG ${ROOTFS}${YUNIONWEB}
  fi

  cp -r /mnt/rpms/updates $ROOTFS/opt/

  UPDATE_REPO=/opt/updates

  YUNIONSETUP=$(ls /mnt/yunionsetup | tail -n 1)

  if [ -n "$YUNIONSETUP" ]; then
    echo "Extract $YUNIONSETUP ..."
    gunzip -c /mnt/yunionsetup/$YUNIONSETUP | tar xf - -C $ROOTFS/opt/
  fi

  echo "CLOUD_DIR=/opt/cloud
YUNIONWEB=$YUNIONWEB
MYSQL_HOST=$IP
MYSQL_PORT=3306
MYSQL_ROOT_PASS=$DB_PASS
INTERFACE=$NIC
REGION=$REGION
ZONE=$ZONE
DOMAIN=$CLOUD_DOMAIN
DNS_SERVER=$DNS
CUSTOM_REPO=
UPDATE_REPO=$UPDATE_REPO
SYSADMIN_PASSWORD=$SYSADMIN_PASS" > $ROOTFS/opt/yunionsetup/vars

  chroot $ROOTFS chown -R yunion:yunion /opt/yunionsetup

elif [ "$ROLE" == "host" ]; then

  echo "YUNION_REGION=$REGION
YUNION_KEYSTONE=$AUTHURI
YUNION_HOST_ADMIN=$HOSTADMIN
YUNION_HOST_PASSWORD=$HOSTPASS
YUNION_HOST_PROJECT=$HOSTPROJECT
YUNION_MASTER_BRIDGE=br0
YUNION_START=yes" >> $ROOTFS//etc/sysconfig/yunionauth

fi

mkdir -p $ROOTFS/opt/cloud/workspace
mount /dev/$DISK$DATAIDX $ROOTFS/opt/cloud/workspace

chroot $ROOTFS chown -R yunion:yunion /opt/cloud

umount $ROOTFS/opt/cloud/workspace

echo "Umount root disk ..."
umount $ROOTFS
rm -fr $ROOTFS

umount /mnt

echo ""
echo "Rebooting ..."
reboot
