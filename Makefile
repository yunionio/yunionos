BUILD_IMG = "yunionos-build-env:latest"
REGISTRY = "registry.cn-beijing.aliyuncs.com/yunionio"
BUILD_ROOT_IMG = $(REGISTRY)/buildroot:2017.02.11-0

BUILD_ROOT_OUTPUT_DIR = $(CURDIR)/output
BUNDLE_OUTPUT_DIR = $(CURDIR)/output_bundle

KERNEL_5_12_9_RPM ?= kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm

# find from: https://centos.pkgs.org/7/centos-updates-x86_64/kernel-3.10.0-1160.25.1.el7.x86_64.rpm.html
KERNEL_3_10_0_RPM ?= kernel-3.10.0-1160.6.1.el7.yn20201125.x86_64.rpm


download-kernel-rpm:
	wget https://mirror.rackspace.com/elrepo/kernel/el7/x86_64/RPMS/kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm

download-kernel-3-10-rpm:
	wget https://iso.yunion.cn/3.7/rpms/packages/kernel/kernel-3.10.0-1160.6.1.el7.yn20201125.x86_64.rpm

pxelinux-update:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.pxelinux --output ./pxelinux .

buildroot-image:
	docker build -t $(BUILD_ROOT_IMG) -f Dockerfile.buildroot .

docker-buildroot:
	./scripts/buildroot-run.sh make

bundle-pxe:
	./bin/mosbundle -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_5_12_9_RPM) $(BUNDLE_OUTPUT_DIR) pxe

docker-bundle:
	./scripts/bundle-run.sh

bundle-iso:
	./bin/mosbundle -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_3_10_0_RPM) $(BUNDLE_OUTPUT_DIR) iso

make-rpm:
	./bin/makerpm $(BUNDLE_OUTPUT_DIR)

docker-make-rpm:
	docker run --rm \
		--name docker-centos-build-baremetal \
		-v $(CURDIR):/data \
		registry.cn-beijing.aliyuncs.com/yunionio/centos-build:1.1-4 \
		/bin/bash -c "make -C /data make-rpm"
