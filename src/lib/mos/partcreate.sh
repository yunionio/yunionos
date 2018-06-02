#!/bin/sh

set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/lib/mos

if [ "$#" -lt 5 ]; then
    echo $#
    echo "Usage: $0 <token> <image_url> <image_id> <root_offset> <is_format_fs> <size:type> ..."
    exit 1
fi

TOKEN=$1 # "7b3eb8be88c94e9ba4b65fa428d5a53e"
shift
IMGURL=$1 # "http://10.168.44.160:9292/v1"
shift
IMGID=$1 # "5802bbe8-a55e-47a7-9337-6912724eb63e"
shift
ROOTOFFSET=$1 # 2 # GiB
shift
FORMAT=$1 # 1 # 0 | 1
shift
# SIZE=32 # MiB
# FS=swap # swap, ext2, ext3, ext4, ext4dev, xfs


DISK=$(lsdisk | head -n 1 | awk '{print $1}')

DISKCNT=$(lsdisk | wc -l)

if [ -z "$DISK" ]; then
    exit 1
fi

LVM=""
if [ "$DISKCNT" -gt 1 ]; then
    LVM="yes"
fi

rm -fr /tmp/$IMGID
wget -q --header "X-Auth-Token: $TOKEN" $IMGURL/images/$IMGID -P /tmp/

qemu-nbd -c /dev/nbd0 /tmp/$IMGID

SIZE=$(cat /sys/block/nbd0/size)

dd if=/dev/zero of=/dev/$DISK bs=$((SIZE*512)) count=1

dd if=/dev/nbd0 of=/dev/$DISK > /dev/null

qemu-nbd -d /dev/nbd0

partprobe

sleep 2

OFFSET=$((ROOTOFFSET*1024*1024*2+1))

lastdev() {
    ls /dev/$DISK* | tail -n 1
}

wait_lastdev() {
    local OLASTDEV=$1
    local LASTDEV=$(lastdev)
    while [ "$OLASTDEV" == "$LASTDEV" ]; do
        sleep 1
        local LASTDEV=$(lastdev)
    done
    echo $LASTDEV
}

disk_type() {
    if [ "$1" == "swap" ]; then
        echo "linux-swap"
    else
        echo "ext2"
    fi
}

mkfs_util() {
    case $1 in
        swap)
            echo "mkswap"
            ;;
        ext2|ext3|ext4|ext4dev)
            echo "mkfs.$FS"
            ;;
        xfs)
            echo "mkfs.xfs"
            ;;
        *)
            echo ""
            ;;
    esac
}

single_disk_setup() {
    local START=$OFFSET
    for FSSIZE in $@
    do
        local FS=${FSSIZE#*:}
        local SIZE=${FSSIZE%%:*}
        if [ "$SIZE" == "-1" ]; then
            local END=$SIZE
        else
            local END=$((START+$SIZE*1024*2))
        fi
        local TYPE=$(disk_type $FS)
        local MKFS=$(mkfs_util $FS)
        echo $SIZE $FS $START $END $TYPE $MKFS
        OLASTDEV=$(lastdev)
        parted -s /dev/$DISK -- mkpart primary $TYPE ${START}s ${END}s
        START=$((END+1))
        LASTDEV=$(wait_lastdev $OLASTDEV)
        if [ "$FORMAT" == "1" ] && [ -n "$MKFS" ]; then
            echo $MKFS $OLASTDEV $LASTDEV
            $MKFS $LASTDEV > /dev/null 2>&1
        fi
    done
}

VGNAME="data"

lvm_setup() {
    local START=$OFFSET
    local END=-1
    local TYPE=ext2
    OLASTDEV=$(lastdev)
    parted -s /dev/$DISK -- mkpart primary $TYPE ${START}s ${END}s
    LASTDEV=$(wait_lastdev $OLASTDEV)
    OTHERDEV=$(lsdisk | tail +2 | awk '{print "/dev/"$1}' | xargs)
    echo $LASTDEV $OTHERDEV
    if [ "$FORMAT" == "1" ]; then
        vgcreate -y -s 1m $VGNAME $LASTDEV $OTHERDEV
        vgchange -a y $VGNAME
    fi
}

lvm_left_size() {
    vgdisplay data | grep "Free  PE" | awk '{print $5}'
}

lvm_disk_setup() {
    local IDX=1
    for FSSIZE in $@
    do
        local FS=${FSSIZE#*:}
        local SIZE=${FSSIZE%%:*}
        local MKFS=$(mkfs_util $FS)
        if [ "$SIZE" == "-1" ]; then
            SIZE=$(lvm_left_size)
        fi
        local LVNAME=$VGNAME$IDX
        echo $SIZE $LVNAME $MKFS
        lvcreate -l $SIZE $VGNAME -n $LVNAME
        sleep 1
        if [ -n "$MKFS" ]; then
            $MKFS /dev/$VGNAME/$LVNAME
        fi
        IDX=$((IDX+1))
    done
}

if [ -z "$LVM" ]; then
    single_disk_setup $@
else
    lvm_setup
    if [ "$FORMAT" == "1" ]; then
        lvm_disk_setup $@
    fi
fi
