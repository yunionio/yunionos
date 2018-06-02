#!/bin/sh

echo "Huawei system initialization"

/lib/mos/oem/uniCfg -W CustomPowerPolicy:1
/lib/mos/oem/uniCfg -W PCIeSRIOVSupport:1
/lib/mos/oem/uniCfg -W BootType:1
/lib/mos/oem/uniCfg -W VTSupport:1
/lib/mos/oem/uniCfg -W VTdSupport:1
/lib/mos/oem/uniCfg -W CREnable:1
