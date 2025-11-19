BUILD_IMG = "yunionos-build-env:latest"
REGISTRY = "registry.cn-beijing.aliyuncs.com/yunionio"
platform ?= linux/arm64,linux/amd64,linux/riscv64

BUILD_ROOT_OUTPUT_DIR = $(CURDIR)/../output
BUILD_ROOT_OUTPUT_DIR_ARM64 = $(CURDIR)/../output_arm64
BUILD_ROOT_OUTPUT_DIR_RISC64 = $(CURDIR)/../output_riscv64
BUNDLE_OUTPUT_DIR = $(CURDIR)/../output_bundle
BUNDLE_OUTPUT_DIR_ARM64 = $(CURDIR)/../output_bundle_arm64
BUNDLE_OUTPUT_DIR_RISC64 = $(CURDIR)/../output_bundle_riscv64

OUTPUT_ROOTFS_AMD64 = $(CURDIR)/output_rootfs/amd64
OUTPUT_ROOTFS_ARM64 = $(CURDIR)/output_rootfs/arm64
OUTPUT_ROOTFS_RISC64 = $(CURDIR)/output_rootfs/riscv64

extract-bundle-rootfs-amd64:
	rm -rf $(OUTPUT_ROOTFS_AMD64)
	mkdir -p $(OUTPUT_ROOTFS_AMD64)
	cp $(BUNDLE_OUTPUT_DIR)/initramfs $(OUTPUT_ROOTFS_AMD64)/initramfs.gz
	(cd $(OUTPUT_ROOTFS_AMD64) && gunzip initramfs.gz && cpio -idmv < initramfs)
	rm -rf $(OUTPUT_ROOTFS_AMD64)/initramfs

extract-bundle-rootfs-arm64:
	rm -rf $(OUTPUT_ROOTFS_ARM64)
	mkdir -p $(OUTPUT_ROOTFS_ARM64)
	cp $(BUNDLE_OUTPUT_DIR_ARM64)/initramfs $(OUTPUT_ROOTFS_ARM64)/initramfs.gz
	(cd $(OUTPUT_ROOTFS_ARM64) && gunzip initramfs.gz && cpio -idmv < initramfs)
	rm -rf $(OUTPUT_ROOTFS_ARM64)/initramfs

extract-bundle-rootfs-riscv64:
	rm -rf $(OUTPUT_ROOTFS_RISC64)
	mkdir -p $(OUTPUT_ROOTFS_RISC64)
	cp $(BUNDLE_OUTPUT_DIR_RISC64)/initramfs $(OUTPUT_ROOTFS_RISC64)/initramfs.gz
	(cd $(OUTPUT_ROOTFS_RISC64) && gunzip initramfs.gz && cpio -idmv < initramfs)
	rm -rf $(OUTPUT_ROOTFS_RISC64)/initramfs

VERSION = "v4.0.0-20251112.0"

docker-yunion-rootfs-image:
	docker buildx build --platform $(platform) --push \
		-t $(REGISTRY)/yunion-rootfs:$(VERSION) -f ./Dockerfile.yunion-rootfs .
