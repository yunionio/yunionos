#!/bin/sh

huawei() {
    /lib/mos/oem/huawei.sh
}

dell() {
    /lib/mos/oem/dell.sh
}

OEM=$(dmidecode -t 1 | grep "Manufacturer" | awk '{print tolower($0)}')

case "$OEM" in
    *huawei*)
        huawei
        ;;
    *dell*)
        dell
        ;;
    *)
        echo "Unknown manufacture"
        ;;
esac
