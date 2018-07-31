#!/bin/sh

set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

TOKEN=$1 # "7b3eb8be88c94e9ba4b65fa428d5a53e"
IMGURL=$2 # "http://10.168.44.160:9292/v1"
IMGID=$3 # "5802bbe8-a55e-47a7-9337-6912724eb63e"
DISK=$4

if [ -z "$IMGID" ]; then
    echo "Usage: $0 <token> <url> <imgid> [disk_dev]"
    exit 1
fi

if [ -z "$DISK" ]; then
    DISK=$(lsdisk --raid | head -n 1 | awk '{print $1}')
    if [ -z "$DISK" ]; then
        DISK=$(lsdisk --scsi | head -n 1 | awk '{print $1}')
    fi
fi

if [ -z "$DISK" ]; then
    echo "No root disk found"
    exit 1
fi

rm -fr /tmp/$IMGID /tmp/$IMGID.raw

wget -q --header "X-Auth-Token: $TOKEN" $IMGURL/images/$IMGID -P /tmp/

# destroy backup partition of GPT at the end of disk drive
SECTOR=$(cat /sys/class/block/$DISK/size)
COUNT=34
dd if=/dev/zero of=/dev/$DISK bs=512 count=$COUNT seek=$((SECTOR-COUNT))

qemu-img info /tmp/$IMGID

# clone image at the begining of disk drive
qemu-img convert -O raw /tmp/$IMGID /dev/$DISK

# turn off cache
sysctl -w vm.drop_caches=3
hdparm -f /dev/$DISK
hdparm -z /dev/$DISK

# repair disk partition
LABEL=$(parted -s /dev/$DISK -- print | grep "Partition Table:" | awk '{print $3}')

case "$LABEL" in
    gpt)
        echo "GPT partion"
        echo -n -e "r\ne\nY\nw\nY\nY\n" | gdisk /dev/$DISK
        ;;
    msdos)
        echo "MSDOS partion"
        echo -n -e "r\nf\nY\nw\nY\n" | gdisk /dev/$DISK
        ;;
esac

hdparm -f /dev/$DISK
hdparm -z /dev/$DISK
