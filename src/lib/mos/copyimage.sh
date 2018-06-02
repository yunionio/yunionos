#!/bin/sh

set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

IMAGE=$1
DISK=$2

if [ -z "$DISK" ]; then
  echo "Usage: $0 <image> <disk>"
  exit 1
fi

# destroy backup partition of GPT at the end of disk drive
SECTOR=$(cat /sys/class/block/$DISK/size)
COUNT=34
dd if=/dev/zero of=/dev/$DISK bs=512 count=$COUNT seek=$((SECTOR-COUNT))

# clone image at the begining of disk drive
qemu-img convert -O raw $IMAGE /dev/$DISK

# turn off cache
sync
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

sync
sysctl -w vm.drop_caches=3
hdparm -f /dev/$DISK
hdparm -z /dev/$DISK
