#!/bin/sh

set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

DEV=$1

if [ -z "$DEV" ]; then
    echo "Usage: $0 <dev>"
    exit 1
fi

DISK=$(lsdisk --raid | head -n 1 | awk '{print $1}')
if [ -z "$DISK" ]; then
    DISK=$(lsdisk --scsi | head -n 1 | awk '{print $1}')
fi

DEV=$(basename $DEV)

if [ ! -d /sys/block/$DISK/$DEV ]; then
    echo "No such device" $DEV
    exit 1
fi

INDEX=$(cat /sys/block/$DISK/$DEV/partition)

if [ -z "$INDEX" ]; then
    echo "Not a partition " $DEV
    exit 1
fi

parted -s /dev/$DISK -- print | grep "^ $INDEX " | awk '{print $6}'
