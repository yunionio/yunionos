#!/bin/sh

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos


BLOCK=512
COUNT=34
for DISK in $(lsdisk | awk '{print $1}')
do
    SECTOR=$(cat /sys/class/block/$DISK/size)
    dd if=/dev/zero of=/dev/$DISK bs=$BLOCK count=$COUNT
    dd if=/dev/zero of=/dev/$DISK bs=$BLOCK count=$COUNT seek=$((SECTOR-COUNT))
    hdparm -z /dev/$DISK
done
