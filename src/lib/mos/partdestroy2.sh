#!/bin/sh

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

DISK=$(lsdisk | head -n 1 | awk '{print $1}')
DISKCNT=$(lsdisk | wc -l)

echo $DISK $DISKCNT

LVM=""
if [ "$DISKCNT" -gt 1 ]; then
    LVM="yes"
fi
LVM="" # force no LVM

if [ -n "$LVM" ]; then
    for VG in $(vgdisplay | grep "VG Name" | awk '{print $3}')
    do
        echo $VG
        vgchange -a n $VG
        vgremove -f $VG
    done
fi

SIZE=$((32*1024))
dd if=/dev/zero of=/dev/$DISK bs=$((SIZE*512)) count=1
hdparm -z /dev/$DISK
