#!/bin/sh

set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

DEV=$1

if [ -z "$DEV" ]; then
    echo "Usage: $0 <dev>"
    exit 1
fi

DEV=$(basename $DEV)

DISK=

for d in $(ls /sys/block/)
do
    if [ "$d" == "${DEV:0:${#d}}" ] && [ -e /sys/block/$d/device ]; then
        DISK=$d
        break
    fi
done

if [ -z "$DISK" ]; then
    echo "Not a partition " $DEV
    exit 1
fi

INDEX=${DEV:${#DISK}}

if [ -z "$INDEX" ]; then
    echo "Not a parition"
    exit 1
fi

parted -s /dev/$DISK -- print | grep "^ $INDEX " | awk '{print $6}'
