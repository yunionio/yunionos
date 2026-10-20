BUILD_IMG = "yunionos-build-env:latest"
# Override REGISTRY for CI/Docker Hub push only, e.g.:
#   make docker-yunionos-image REGISTRY=docker.io/yunion YUNIONOS_VERSION=v4.1.0-20261020.0
# Buildroot tooling image stays on Aliyun regardless of REGISTRY.
ALIYUN_REGISTRY = registry.cn-beijing.aliyuncs.com/yunionio
REGISTRY ?= $(ALIYUN_REGISTRY)
BUILD_ROOT_VERSION = "2025.05.3"
BUILD_ROOT_IMG = $(ALIYUN_REGISTRY)/buildroot:$(BUILD_ROOT_VERSION)-5
platform?=linux/amd64,linux/arm64,linux/riscv64


BUILD_ROOT_OUTPUT_DIR = $(CURDIR)/output
BUILD_ROOT_OUTPUT_DIR_ARM64 = $(CURDIR)/output_arm64
BUILD_ROOT_OUTPUT_DIR_RISCV64 = $(CURDIR)/output_riscv64
ROOTFS_AMD64 = $(BUILD_ROOT_OUTPUT_DIR)/images/rootfs.tar
ROOTFS_ARM64 = $(BUILD_ROOT_OUTPUT_DIR_ARM64)/images/rootfs.tar
ROOTFS_RISCV64 = $(BUILD_ROOT_OUTPUT_DIR_RISCV64)/images/rootfs.tar
BUNDLE_OUTPUT_DIR = $(CURDIR)/output_bundle
BUNDLE_OUTPUT_DIR_VM = $(CURDIR)/output_bundle_vm
BUNDLE_OUTPUT_DIR_ARM64 = $(CURDIR)/output_bundle_arm64
BUNDLE_OUTPUT_DIR_ARM64_VM = $(CURDIR)/output_bundle_arm64_vm
BUNDLE_OUTPUT_DIR_RISC64 = $(CURDIR)/output_bundle_riscv64
BUNDLE_OUTPUT_DIR_RISC64_VM = $(CURDIR)/output_bundle_riscv64_vm

KERNEL_ARM_6_DEB ?= linux-image-6.1.0-50-arm64_6.1.176-1_arm64.deb

KERNEL_AMD64_6_DEB ?= linux-image-6.1.0-50-amd64_6.1.176-1_amd64.deb

KERNEL_RISC_RPM ?= linux-core-7.2.6-1.0_555.2.or.riscv64.rpm

KERNEL_MODULES_RISC_RPM ?= linux-modules-7.2.6-1.0_555.2.or.riscv64.rpm

OPENRUYI_RISCV_REPO ?= https://repo.build.openruyi.cn/openruyi/riscv64/riscv64

DEBIAN_FIRMWARE_DEB ?= firmware-bnx2x_20260916-1_all.deb

$(DEBIAN_FIRMWARE_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/non-free-firmware/f/firmware-nonfree/$(DEBIAN_FIRMWARE_DEB)

download-debian-firmware: $(DEBIAN_FIRMWARE_DEB)

$(KERNEL_ARM_6_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-arm64/$(KERNEL_ARM_6_DEB)

download-kernel-arm-6-deb: $(KERNEL_ARM_6_DEB)

$(KERNEL_AMD64_6_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-amd64/$(KERNEL_AMD64_6_DEB)

download-kernel-amd64-6-deb: $(KERNEL_AMD64_6_DEB)

$(KERNEL_RISC_RPM):
	wget -c $(OPENRUYI_RISCV_REPO)/$(KERNEL_RISC_RPM)

$(KERNEL_MODULES_RISC_RPM):
	wget -c $(OPENRUYI_RISCV_REPO)/$(KERNEL_MODULES_RISC_RPM)

download-kernel-risc: $(KERNEL_RISC_RPM) $(KERNEL_MODULES_RISC_RPM)

pxelinux-update:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.pxelinux --output ./pxelinux .

buildroot-image:
	docker buildx build --platform $(platform) --build-arg FORCE_UNSAFE_CONFIGURE=1 -t $(BUILD_ROOT_IMG) -f Dockerfile.buildroot-$(BUILD_ROOT_VERSION) . --push

docker-buildroot:
	./scripts/buildroot-run.sh make

docker-buildroot-arm64:
	TARGET_ARCH=aarch64 ./scripts/buildroot-run.sh make

docker-buildroot-riscv64:
	TARGET_ARCH=riscv64 ./scripts/buildroot-run.sh make

BUNDLE_BM_CMD = ./bin/mosbundle -f ./$(DEBIAN_FIRMWARE_DEB)  -r ./remove_files_list.txt

BUNDLE_VM_CMD = ./bin/mosbundle -r ./vm_remove_files_list.txt -m ./vm_etc_modules

# rootfs is built by docker-buildroot*; do not rebuild here (slow / separate container)
$(ROOTFS_AMD64):
	@echo "ERROR: $@ missing. Run: make docker-buildroot" >&2
	@false

$(ROOTFS_ARM64):
	@echo "ERROR: $@ missing. Run: make docker-buildroot-arm64" >&2
	@false

$(ROOTFS_RISCV64):
	@echo "ERROR: $@ missing. Run: make docker-buildroot-riscv64" >&2
	@false

bundle-pxe: download-debian-firmware download-kernel-amd64-6-deb $(ROOTFS_AMD64)
	 $(BUNDLE_BM_CMD) -e ./extra_modules $(ROOTFS_AMD64) ./$(KERNEL_AMD64_6_DEB) $(BUNDLE_OUTPUT_DIR) pxe

bundle-pxe-vm: download-debian-firmware download-kernel-amd64-6-deb $(ROOTFS_AMD64)
	 $(BUNDLE_VM_CMD) $(ROOTFS_AMD64) ./$(KERNEL_AMD64_6_DEB) $(BUNDLE_OUTPUT_DIR_VM) pxe

bundle-pxe-arm64: download-debian-firmware download-kernel-arm-6-deb $(ROOTFS_ARM64)
	ARCH=aarch64 $(BUNDLE_BM_CMD) $(ROOTFS_ARM64) ./$(KERNEL_ARM_6_DEB) $(BUNDLE_OUTPUT_DIR_ARM64) pxe

bundle-pxe-arm64-vm: download-debian-firmware download-kernel-arm-6-deb $(ROOTFS_ARM64)
	ARCH=aarch64 $(BUNDLE_VM_CMD) $(ROOTFS_ARM64) ./$(KERNEL_ARM_6_DEB) $(BUNDLE_OUTPUT_DIR_ARM64_VM) pxe

bundle-pxe-riscv64: download-debian-firmware download-kernel-risc $(ROOTFS_RISCV64)
	ARCH=riscv64 $(BUNDLE_BM_CMD) -m ./src_riscv64/etc/modules $(ROOTFS_RISCV64) ./$(KERNEL_RISC_RPM) $(BUNDLE_OUTPUT_DIR_RISC64) pxe ./$(KERNEL_MODULES_RISC_RPM)

bundle-pxe-riscv64-vm: download-debian-firmware download-kernel-risc $(ROOTFS_RISCV64)
	ARCH=riscv64 ./bin/mosbundle -r ./vm_remove_files_list.txt -m ./vm_etc_modules_riscv64 $(ROOTFS_RISCV64) ./$(KERNEL_RISC_RPM) $(BUNDLE_OUTPUT_DIR_RISC64_VM) pxe ./$(KERNEL_MODULES_RISC_RPM)

docker-bundle-x86_64: $(ROOTFS_AMD64)
	./scripts/bundle-run.sh

docker-bundle-arm64: $(ROOTFS_ARM64)
	TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

docker-bundle-riscv64: $(ROOTFS_RISCV64)
	TARGET_ARCH=riscv64 ./scripts/bundle-run.sh

docker-bundle-vm-x86_64: $(ROOTFS_AMD64)
	FOR_VM=true ./scripts/bundle-run.sh

docker-bundle-vm-arm64: $(ROOTFS_ARM64)
	FOR_VM=true TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

docker-bundle-vm-riscv64: $(ROOTFS_RISCV64)
	FOR_VM=true TARGET_ARCH=riscv64 ./scripts/bundle-run.sh

docker-bundle-vm: docker-bundle-vm-x86_64 docker-bundle-vm-arm64 docker-bundle-vm-riscv64

docker-bundle: docker-bundle-x86_64 docker-bundle-arm64 docker-bundle-riscv64

docker-bundle-all: docker-bundle docker-bundle-vm

make-rpm:
	./bin/makerpm $(BUNDLE_OUTPUT_DIR) $(BUNDLE_OUTPUT_DIR_ARM64)

docker-make-rpm:
	docker run --rm \
		--name docker-centos-build-baremetal \
		-v $(CURDIR):/data \
		registry.cn-beijing.aliyuncs.com/yunionio/centos-build:1.1-4 \
		/bin/bash -c "make -C /data make-rpm"

YUNIONOS_VERSION ?= v4.1.0-20261020.0
YUNIONOS_VERSION_VM = $(YUNIONOS_VERSION)-vm

docker-yunionos-image:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION) -f ./Dockerfile.yunionos .

docker-yunionos-image-vm:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION_VM) -f ./Dockerfile.yunionos-vm .

docker-yunionos-image-all: docker-buildroot docker-buildroot-arm64 docker-buildroot-riscv64 docker-bundle-all docker-yunionos-image docker-yunionos-image-vm

extract-bundle-rootfs:
	sudo make -C images extract-bundle-rootfs-amd64
	sudo make -C images extract-bundle-rootfs-arm64
	sudo make -C images extract-bundle-rootfs-riscv64

docker-yunion-rootfs-image: extract-bundle-rootfs
	sudo make -C images docker-yunion-rootfs-image
