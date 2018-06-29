#!/bin/sh

TOOL=/opt/MegaRAID/MegaCli/MegaCli64
ADAPT=0

error() {
  echo "Error: $1"
  exit 1
}

get_lvs() {
  $TOOL -LDInfo -Lall -a$ADAPT | grep "^Virtual Drive" | awk '{print $3}'
}

remove_lv() {
  local INDEX=$1
  $TOOL -CfgLdDel -L$INDEX -Force -a$ADAPT
}

remove_lvs() {
  for LV in $(get_lvs)
  do
    remove_lv $LV
  done
}

get_pv_encid() {
  ENC_CNT=$($TOOL -PDList -a$ADAPT | grep "^Enclosure Device ID" | awk '{print $4}' | uniq | wc -l)
  if [ "$ENC_CNT" -ne "1" ]; then
    error "Enclosure count $ENC_CNT, cannot handle this situation, quit ..."
  fi
  $TOOL -PDList -a$ADAPT | grep "^Enclosure Device ID" | awk '{print $4}' | uniq
}

get_pv_slots() {
  $TOOL -PDList -a$ADAPT | grep "^Slot Number" | awk '{print $3}'
}

get_pvs() {
  local ENCID=$(get_pv_encid)
  for s in $(get_pv_slots)
  do
    echo $ENCID:$s
  done
}

PV_CNT=$(get_pv_slots | wc -l)

build_raid10() {
  if [ "$PV_CNT" -eq "2" ]; then
    _build_raid1
  elif [ "$PV_CNT" -ge "4" ]; then
    _build_raid10
  fi
}

get_raid10_pvs() {
  ARRAY=
  for pv in $(get_pvs)
  do
    CNT=$((CNT+1))
    if [ -n "$ARRAY" ]; then
      echo "${ARRAY},${pv}"
      ARRAY=
    else
      ARRAY=$pv
    fi
  done
}

_build_raid10() {
  if [ "$PV_CNT" -lt "4" ]; then
    error "Not enough disks count for RAID10, at least 4 disks"
  fi
  IDX=0
  DISKS=
  for arr in $(get_raid10_pvs)
  do
    DISKS="$DISKS -Array$IDX[$arr]"
    IDX=$((IDX+1))
  done
  echo $TOOL -CfgSpanAdd -r10 $DISKS -a$ADAPT
  $TOOL -CfgSpanAdd -r10 $DISKS -a$ADAPT
}

_build_raid1() {
  if [ "$PV_CNT" -ne 2 ]; then
    error "Not enough disks count for RAID1, needs 2 disks"
  fi
  _build_raid 1
}

build_raid0() {
  if [ "$PV_CNT" -lt 1 ]; then
    error "Not enough disks count for RAID0, at least 1 disks"
  fi
  _build_raid 0
}

build_raid5() {
  if [ "$PV_CNT" -lt 3 ]; then
    error "Not enough disks count for RAID5, at least 3 disks"
  fi
  _build_raid 5
}

_build_raid() {
  LEVEL=$1
  DISKS=
  for pv in $(get_pvs)
  do
    if [ -n "$DISKS" ]; then
      DISKS="${DISKS},"
    fi
    DISKS="${DISKS}${pv}"
  done
  echo $TOOL -CfgLdAdd -r$LEVEL [$DISKS] -a$ADAPT
  $TOOL -CfgLdAdd -r$LEVEL [$DISKS] -a$ADAPT
}

case $1 in
  RAID0)
    remove_lvs
    build_raid0
    ;;
  RAID10)
    remove_lvs
    build_raid10
    ;;
  RAID5)
    remove_lvs
    build_raid5
    ;;
  CLEAN)
    remove_lvs
    ;;
  *)
    echo "LVs:" $(get_lvs | xargs)
    echo "PVs:" $(get_pvs | xargs)
    error "${0##*/} RAID10|RAID5|CLEAN"
    ;;
esac
