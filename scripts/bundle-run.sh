#!/bin/bash

BUILDROOT_IMG="registry.cn-beijing.aliyuncs.com/yunionio/buildroot:2017.02.11-0"

docker run \
    --rm \
    -ti \
    -v $(pwd):/yunionos \
    ${BUILDROOT_IMG} make -C /yunionos bundle-pxe
