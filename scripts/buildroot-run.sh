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

OUTPUT_DIR=/buildroot_output
BUILDROOT_DIR=/root/buildroot
BUILDROOT_IMG="registry.cn-beijing.aliyuncs.com/yunionio/buildroot:2017.02.11-0"

cp $(pwd)/rootfs/buildroot_conf/rootfs.201702.11-5.conf $(pwd)/output/.config
cp $(pwd)/rootfs/buildroot_conf/busybox-config-20180809 $(pwd)/output/

DOCKER_RUN="docker run
    --rm
    -ti
    -u $(id -u ${USER}):$(id -g ${USER})
    -v $(pwd)/data:$BUILDROOT_DIR/data
    -v $(pwd)/external:$BUILDROOT_DIR/external
    -v $(pwd)/rootfs_overlay:$BUILDROOT_DIR/rootfs_overlay
    -v $(pwd)/images:$BUILDROOT_DIR/images
    -v $(pwd)/output:$OUTPUT_DIR
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
