#!/bin/sh

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

DISK=$(lsdisk | head -n 1 | awk '{print $1}')
DISKCNT=$(lsdisk | wc -l)

LVM=""
if [ "$DISKCNT" -gt 1 ]; then
    LVM="yes"
fi

if [ "$1" == "nolvm" ]; then
    LVM=""
fi

list_lvm() {
    DEVPATH=/sys/block
    for dev in $(ls $DEVPATH)
    do
        if [ -f $DEVPATH/$dev/dm/name ]; then
            NAME=$(cat $DEVPATH/$dev/dm/name)
            SIZE=$(cat $DEVPATH/$dev/size)
            echo /dev/mapper/$NAME $((SIZE*512/1024/1024))
        fi
    done
}

list_part() {
    parted -s /dev/$DISK -- unit MiB print | grep "primary" | awk -v dev="/dev/$DISK" '{gsub("MiB","",$4); print dev $1 " " $4}'
}

if [ -n "$LVM" ]; then
    list_lvm
else
    list_part
fi
