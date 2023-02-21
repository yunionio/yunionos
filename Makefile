BUILD_IMG = "yunionos-build-env:latest"
REGISTRY = "registry.cn-beijing.aliyuncs.com/yunionio"
BUILD_ROOT_VERSION = "2021.08.2"
BUILD_ROOT_IMG = $(REGISTRY)/buildroot:$(BUILD_ROOT_VERSION)-0

BUILD_ROOT_OUTPUT_DIR = $(CURDIR)/output
BUILD_ROOT_OUTPUT_DIR_ARM64 = $(CURDIR)/output_arm64
BUNDLE_OUTPUT_DIR = $(CURDIR)/output_bundle
BUNDLE_OUTPUT_DIR_ARM64 = $(CURDIR)/output_bundle_arm64

KERNEL_5_14_15_RPM ?= kernel-ml-5.14.15-1.el7.elrepo.x86_64.rpm

KERNEL_5_12_9_RPM ?= kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm

# find from: https://centos.pkgs.org/7/centos-updates-x86_64/kernel-3.10.0-1160.25.1.el7.x86_64.rpm.html
KERNEL_3_10_0_RPM ?= kernel-3.10.0-1160.6.1.el7.yn20201125.x86_64.rpm

KERNEL_ARM_5_DEB ?= linux-image-5.19.0-0.deb11.2-arm64_5.19.11-1~bpo11+1_arm64.deb

KERNEL_AMD64_5_DEB ?= linux-image-5.19.0-0.deb11.2-amd64_5.19.11-1~bpo11+1_amd64.deb

KERNEL_ARM_6_DEB ?= linux-image-6.0.0-6-arm64_6.0.12-1_arm64.deb

KERNEL_AMD64_6_DEB ?= linux-image-6.0.0-6-amd64_6.0.12-1_amd64.deb

download-kernel-rpm:
	wget -c https://mirror.rackspace.com/elrepo/kernel/el7/x86_64/RPMS/$(KERNEL_5_14_15_RPM)


download-kernel-5-12-9-rpm:
	wget -c https://mirror.rackspace.com/elrepo/kernel/el7/x86_64/RPMS/kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm

download-kernel-3-10-rpm:
	wget -c https://iso.yunion.cn/3.7/rpms/packages/kernel/kernel-3.10.0-1160.6.1.el7.yn20201125.x86_64.rpm

download-debian-firmware:
	wget -c https://mirrors.aliyun.com/debian/pool/non-free/f/firmware-nonfree/firmware-bnx2x_20221214-2_all.deb

download-kernel-arm-5-deb:
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-arm64/$(KERNEL_ARM_5_DEB)

download-kernel-amd64-5-deb:
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-amd64/$(KERNEL_AMD64_5_DEB)

download-kernel-arm-6-deb:
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-arm64/$(KERNEL_ARM_6_DEB)

download-kernel-amd64-6-deb:
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-amd64/$(KERNEL_AMD64_6_DEB)

pxelinux-update:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.pxelinux --output ./pxelinux .

buildroot-image:
	docker build -t $(BUILD_ROOT_IMG) -f Dockerfile.buildroot-$(BUILD_ROOT_VERSION) .

docker-buildroot:
	#rm -rf $(BUILD_ROOT_OUTPUT_DIR)/target
	#find $(BUILD_ROOT_OUTPUT_DIR) -name ".stamp_target_installed" | xargs rm -rf
	./scripts/buildroot-run.sh make

docker-buildroot-arm64:
	TARGET_ARCH=aarch64 ./scripts/buildroot-run.sh make

BUNDLE_PXE_CMD = ./bin/mosbundle -f ./firmware-bnx2x_20221214-2_all.deb

bundle-pxe:
	 $(BUNDLE_PXE_CMD) -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_AMD64_6_DEB) $(BUNDLE_OUTPUT_DIR) pxe

bundle-pxe-arm64:
	ARCH=aarch64 $(BUNDLE_PXE_CMD) ./output_arm64/images/rootfs.tar ./$(KERNEL_ARM_6_DEB) $(BUNDLE_OUTPUT_DIR_ARM64) pxe

docker-bundle:
	./scripts/bundle-run.sh

docker-bundle-arm64:
	TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

docker-bundle-all: docker-bundle docker-bundle-arm64

bundle-iso:
	./bin/mosbundle -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_5_14_15_RPM) $(BUNDLE_OUTPUT_DIR) iso

make-rpm:
	./bin/makerpm $(BUNDLE_OUTPUT_DIR)

docker-make-rpm:
	docker run --rm \
		--name docker-centos-build-baremetal \
		-v $(CURDIR):/data \
		registry.cn-beijing.aliyuncs.com/yunionio/centos-build:1.1-4 \
		/bin/bash -c "make -C /data make-rpm"

YUNIONOS_VERSION = "v0.1.8-20230221.2"

docker-yunionos-image:
	docker buildx build --platform linux/arm64,linux/amd64 --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION) -f ./Dockerfile.yunionos .

extract-bundle-rootfs:
	sudo make -C images extract-bundle-rootfs-amd64
	sudo make -C images extract-bundle-rootfs-arm64

docker-yunion-rootfs-image: extract-bundle-rootfs
	sudo make -C images docker-yunion-rootfs-image
