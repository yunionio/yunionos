#!/bin/bash
# REF: https://github.com/AdvancedClimateSystems/docker-buildroot/blob/master/scripts/run.sh
# Start container and start process inside container.
#
# Example:
#   ./run.sh            Start a sh shell inside container.
#   ./run.sh ls -la     Run `ls -la` inside container.
#
# Calls to `make` are intercepted and the "O=/buildroot_output" is added to
# command. So calling `./run.sh make savedefconfig` will run `make
# savedefconfig O=/buildroot_output` inside the container.
#
# Example:
#   ./run.sh make       Run `make O=/buildroot_output` in container.
#
# When working with Buildroot you probably want to create a config, build
# some products based on that config and save the config for future use.
# Your workflow will look something like this:
#
# ./run.sh make menuconfig
# ./run.sh make
set -e

BUILDROOT_VERSION=2025.05.2
BUILDROOT_DIR=/root/buildroot
BUILDROOT_IMG="registry.cn-beijing.aliyuncs.com/yunionio/buildroot:$BUILDROOT_VERSION-0"
TARGET_ARCH=${TARGET_ARCH:-x86_64}
OUTPUT_DIR=/buildroot_output
OUTPUT_HOST_DIR=output

BUILDROOT_CONFIG=rootfs-x86_64.$BUILDROOT_VERSION-0.conf

if [ $TARGET_ARCH == "aarch64" ]; then
    BUILDROOT_CONFIG=rootfs-aarch64.$BUILDROOT_VERSION-0.conf
    OUTPUT_HOST_DIR=output_arm64
fi

mkdir -p $OUTPUT_HOST_DIR

HOST_BUILDROOT_CONF_DIR=$(pwd)/rootfs/buildroot_conf

cp $HOST_BUILDROOT_CONF_DIR/$BUILDROOT_CONFIG $(pwd)/$OUTPUT_HOST_DIR/.config
cp $HOST_BUILDROOT_CONF_DIR/busybox-config-20180809 $(pwd)/$OUTPUT_HOST_DIR/

# DOCKER_RUN="docker run
    # --rm
    # -ti
    # -u $(id -u ${USER}):$(id -g ${USER})
    # -v $(pwd)/data:$BUILDROOT_DIR/data
    # -v $(pwd)/external:$BUILDROOT_DIR/external
    # -v $(pwd)/rootfs_overlay:$BUILDROOT_DIR/rootfs_overlay
    # -v $(pwd)/images:$BUILDROOT_DIR/images
    # -v $(pwd)/output:$OUTPUT_DIR
    # ${BUILDROOT_IMG}"

DOCKER_RUN="docker run
    --rm
    -ti
    --network host
    -v $HOST_BUILDROOT_CONF_DIR/$BUILDROOT_CONFIG:/root/buildroot/.config
    -v $HOST_BUILDROOT_CONF_DIR/busybox-config-20180809:/root/buildroot/busybox-config-20180809
    -v $(pwd)/$OUTPUT_HOST_DIR:$OUTPUT_DIR
    ${BUILDROOT_IMG}"

make() {
    echo "make O=$OUTPUT_DIR"
}

echo $DOCKER_RUN
if [ "$1" == "make" ]; then
    eval $DOCKER_RUN $(make) ${@:2}
else
    eval $DOCKER_RUN $@
fi
