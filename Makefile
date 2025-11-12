BUILD_IMG = "yunionos-build-env:latest"
REGISTRY = "registry.cn-beijing.aliyuncs.com/yunionio"
BUILD_ROOT_VERSION = "2025.05.3"
BUILD_ROOT_IMG = $(REGISTRY)/buildroot:$(BUILD_ROOT_VERSION)-1
platform?=linux/amd64,linux/arm64,linux/riscv64


BUILD_ROOT_OUTPUT_DIR = $(CURDIR)/output
BUILD_ROOT_OUTPUT_DIR_ARM64 = $(CURDIR)/output_arm64
BUNDLE_OUTPUT_DIR = $(CURDIR)/output_bundle
BUNDLE_OUTPUT_DIR_VM = $(CURDIR)/output_bundle_vm
BUNDLE_OUTPUT_DIR_ARM64 = $(CURDIR)/output_bundle_arm64
BUNDLE_OUTPUT_DIR_ARM64_VM = $(CURDIR)/output_bundle_arm64_vm
BUNDLE_OUTPUT_DIR_RISC64 = $(CURDIR)/output_bundle_riscv64
BUNDLE_OUTPUT_DIR_RISC64_VM = $(CURDIR)/output_bundle_riscv64_vm

KERNEL_ARM_6_DEB ?= linux-image-6.17.7+deb14+1-arm64_6.17.7-2_arm64.deb

KERNEL_AMD64_6_DEB ?= linux-image-6.17.7+deb14+1-amd64_6.17.7-2_amd64.deb

KERNEL_RISC_6_DEB ?= linux-image-6.12.43+deb13-riscv64_6.12.43-1_riscv64.deb

KERNEL_MODULES_RISC_6_DEB ?= linux-image-6.8.0-60-generic_6.8.0-60.63.1_riscv64.deb

KERNEL_MODULES_RISC_6_DEB ?= linux-modules-6.8.0-60-generic_6.8.0-60.63.1_riscv64.deb

DEBIAN_FIRMWARE_DEB ?= firmware-bnx2x_20251021-1_all.deb

$(DEBIAN_FIRMWARE_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/non-free-firmware/f/firmware-nonfree/$(DEBIAN_FIRMWARE_DEB)

download-debian-firmware: $(DEBIAN_FIRMWARE_DEB)

$(KERNEL_ARM_6_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-arm64/$(KERNEL_ARM_6_DEB)

download-kernel-arm-6-deb: $(KERNEL_ARM_6_DEB)

$(KERNEL_AMD64_6_DEB):
	wget -c https://mirrors.aliyun.com/debian/pool/main/l/linux-signed-amd64/$(KERNEL_AMD64_6_DEB)

download-kernel-amd64-6-deb: $(KERNEL_AMD64_6_DEB)

$(KERNEL_RISC_6_DEB):
	wget -c https://mirrors.aliyun.com/ubuntu-ports/pool/main/l/linux-riscv/$(KERNEL_RISC_6_DEB)

$(KERNEL_MODULES_RISC_6_DEB):
	wget -c https://mirrors.aliyun.com/ubuntu-ports/pool/main/l/linux-riscv/$(KERNEL_MODULES_RISC_6_DEB)

download-kernel-risc-6-deb: $(KERNEL_RISC_6_DEB) $(KERNEL_MODULES_RISC_6_DEB)

pxelinux-update:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.pxelinux --output ./pxelinux .

buildroot-image:
	docker buildx build --platform $(platform) -t $(BUILD_ROOT_IMG) -f Dockerfile.buildroot-$(BUILD_ROOT_VERSION) . --push

docker-buildroot:
	./scripts/buildroot-run.sh make

docker-buildroot-arm64:
	TARGET_ARCH=aarch64 ./scripts/buildroot-run.sh make

docker-buildroot-riscv64:
	TARGET_ARCH=riscv64 ./scripts/buildroot-run.sh make

BUNDLE_BM_CMD = ./bin/mosbundle -f ./firmware-bnx2x_20251021-1_all.deb  -r ./remove_files_list.txt

BUNDLE_VM_CMD = ./bin/mosbundle -r ./vm_remove_files_list.txt -m ./vm_etc_modules

bundle-pxe: download-debian-firmware download-kernel-amd64-6-deb
	 $(BUNDLE_BM_CMD) -e ./extra_modules ./output/images/rootfs.tar ./$(KERNEL_AMD64_6_DEB) $(BUNDLE_OUTPUT_DIR) pxe

bundle-pxe-vm: download-debian-firmware download-kernel-amd64-6-deb
	 $(BUNDLE_VM_CMD) ./output/images/rootfs.tar ./$(KERNEL_AMD64_6_DEB) $(BUNDLE_OUTPUT_DIR_VM) pxe

bundle-pxe-arm64: download-debian-firmware download-kernel-arm-6-deb
	ARCH=aarch64 $(BUNDLE_BM_CMD) ./output_arm64/images/rootfs.tar ./$(KERNEL_ARM_6_DEB) $(BUNDLE_OUTPUT_DIR_ARM64) pxe

bundle-pxe-arm64-vm: download-debian-firmware download-kernel-arm-6-deb
	ARCH=aarch64 $(BUNDLE_VM_CMD) ./output_arm64/images/rootfs.tar ./$(KERNEL_ARM_6_DEB) $(BUNDLE_OUTPUT_DIR_ARM64_VM) pxe

bundle-pxe-riscv64: download-debian-firmware download-kernel-risc-6-deb
	ARCH=riscv64 $(BUNDLE_BM_CMD) ./output/images/rootfs.tar ./$(KERNEL_RISC_6_DEB) $(BUNDLE_OUTPUT_DIR_RISC64) pxe ./$(KERNEL_MODULES_RISC_6_DEB)

bundle-pxe-riscv64-vm: download-debian-firmware download-kernel-risc-6-deb
	ARCH=riscv64 $(BUNDLE_VM_CMD) ./output/images/rootfs.tar ./$(KERNEL_RISC_6_DEB) $(BUNDLE_OUTPUT_DIR_RISC64_VM) pxe ./$(KERNEL_MODULES_RISC_6_DEB)

docker-bundle:
	./scripts/bundle-run.sh

docker-bundle-arm64:
	TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

docker-bundle-riscv64:
	TARGET_ARCH=riscv64 ./scripts/bundle-run.sh

docker-bundle-vm-x86_64:
	FOR_VM=true ./scripts/bundle-run.sh

docker-bundle-vm-arm64:
	FOR_VM=true TARGET_ARCH=aarch64 ./scripts/bundle-run.sh

docker-bundle-vm-riscv64:
	FOR_VM=true TARGET_ARCH=riscv64 ./scripts/bundle-run.sh

docker-bundle-vm: docker-bundle-vm-x86_64 docker-bundle-vm-arm64 docker-bundle-vm-riscv64

docker-bundle-all: docker-bundle docker-bundle-arm64 docker-bundle-riscv64 docker-bundle-vm

make-rpm:
	./bin/makerpm $(BUNDLE_OUTPUT_DIR) $(BUNDLE_OUTPUT_DIR_ARM64)

docker-make-rpm:
	docker run --rm \
		--name docker-centos-build-baremetal \
		-v $(CURDIR):/data \
		registry.cn-beijing.aliyuncs.com/yunionio/centos-build:1.1-4 \
		/bin/bash -c "make -C /data make-rpm"

YUNIONOS_VERSION = "v3.10.12-20251030.1"
YUNIONOS_VERSION_VM = $(YUNIONOS_VERSION)-vm

docker-yunionos-image:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION) -f ./Dockerfile.yunionos .

docker-yunionos-image-vm:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION_VM) -f ./Dockerfile.yunionos-vm .

YUNIONOS_VERSION_4.0 = "v4.0.0-20251110.1"
YUNIONOS_VERSION_VM_4.0 = $(YUNIONOS_VERSION_4.0)-vm

docker-yunionos-image-4.0:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION_4.0) -f ./Dockerfile.yunionos .

docker-yunionos-image-vm-4.0:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunionos:$(YUNIONOS_VERSION_VM_4.0) -f ./Dockerfile.yunionos-vm .

docker-yunionos-image-all: docker-buildroot docker-buildroot-arm64 docker-buildroot-riscv64 docker-bundle-all docker-yunionos-image docker-yunionos-image-vm

docker-yunionos-image-all-4.0: docker-buildroot docker-buildroot-arm64 docker-buildroot-riscv64 docker-bundle-all docker-yunionos-image-4.0 docker-yunionos-image-vm-4.0

extract-bundle-rootfs:
	sudo make -C images extract-bundle-rootfs-amd64
	sudo make -C images extract-bundle-rootfs-arm64
	sudo make -C images extract-bundle-rootfs-riscv64

docker-yunion-rootfs-image: extract-bundle-rootfs
	sudo make -C images docker-yunion-rootfs-image
