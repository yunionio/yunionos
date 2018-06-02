#!/bin/sh

MOD=$1

if [ -z "$MOD" ]; then
    echo "Usage: rescan.sh [mptsas|mpt2sas|mpt3sas]"
    exit 1
fi

PATH=/bin:/usr/bin:/sbin:/usr/sbin

sleep 5
INIT_DEV_CNT=$(ls /sys/class/block | wc -l)
rmmod $MOD
sleep 3
modprobe $MOD
DEV_CNT=$(ls /sys/class/block | wc -l)
while [ "$DEV_CNT" -lt "$INIT_DEV_CNT" ]
do
    sleep 1
    DEV_CNT=$(ls /sys/class/block | wc -l)
done
