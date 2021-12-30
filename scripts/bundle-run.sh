#!/bin/bash

BUILDROOT_IMG="registry.cn-beijing.aliyuncs.com/yunionio/buildroot:2021.08.2-0"

TARGET_ARCH=${TARGET_ARCH:-x86_64}

rule=bundle-pxe

if [ $TARGET_ARCH == aarch64 ]; then
    rule=bundle-pxe-arm64
fi

docker run \
    --rm \
    -ti \
    -v $(pwd):/yunionos \
    ${BUILDROOT_IMG} make -C /yunionos $rule
