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

KERNEL_ARM_5_14_0_DEB ?= linux-image-5.14.0-4-arm64_5.14.16-1_arm64.deb

download-kernel-rpm:
	wget https://mirror.rackspace.com/elrepo/kernel/el7/x86_64/RPMS/$(KERNEL_5_14_15_RPM)


download-kernel-5-12-9-rpm:
	wget https://mirror.rackspace.com/elrepo/kernel/el7/x86_64/RPMS/kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm

download-kernel-3-10-rpm:
	wget https://iso.yunion.cn/3.7/rpms/packages/kernel/kernel-3.10.0-1160.6.1.el7.yn20201125.x86_64.rpm

download-kernel-arm-5.14-deb:
	wget https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-arm64/$(KERNEL_ARM_5_14_0_DEB)

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

bundle-pxe:
	./bin/mosbundle -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_5_14_15_RPM) $(BUNDLE_OUTPUT_DIR) pxe

bundle-pxe-arm64:
	ARCH=aarch64 ./bin/mosbundle ./output_arm64/images/rootfs.tar ./$(KERNEL_ARM_5_14_0_DEB) $(BUNDLE_OUTPUT_DIR_ARM64) pxe

docker-bundle:
	./scripts/bundle-run.sh

docker-bundle-arm64:
	TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

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

YUNIONOS_VERSION = "v0.1.1"

docker-yunionos-image:
	docker buildx build --platform linux/arm64,linux/amd64 --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION) -f ./Dockerfile.yunionos .
