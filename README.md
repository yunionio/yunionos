Cloudpods PXE／ISO ROM scripts
===============================

## 使用方法

### 快速编译 yunionos image

这里只说快速制作出 yunionos 容器镜像，其他详细步骤见后面的文档内容。

1. 下载内核和firmware，本地有可跳过:

```bash
# 下载内核
$ make download-kernel-6-deb
```

2. 制作 yunionos 镜像

```bash
$ make docker-yunionos-image-all
```

### 编译 rootfs

rootfs 使用 [buildroot](https://buildroot.org/) 工具进行编译。

为了方便快速制作流程，使用 docker 进行编译。

使用下面的命令制作 buildroot 的 docker 镜像：

```bash
# 制作 buildroot docker 镜像
$ make buildroot-image
```

有了 buildroot 的镜像后，使用该镜像启动容器编译 rootfs，命令如下：

```bash
# 制作 x86_64 rootfs
$ make docker-buildroot

# 制作 arm64 rootfs
$ make docker-buildroot-arm64

# 查看制作好的镜像
$ ls ./output/rootfs.tar
```

### 配置 buildroot config

buildroot 的配置是在 docker 里面做的, 使用 ./scripts/buildroot-run.sh 脚本会启动 buildroot 编译环境, 可以把配置修改后, 再从容器里面拷贝出来.

建议看下 `./scripts/buildroot-run.sh` 脚本的逻辑和 `make docker-buildroot/docker-buildroot-arm64` 的调用关系.

```bash
# 手动进入 buildroot 容器, 配置 buildroot config
# 进入 buildroot bash
$ ./scripts/buildroot-run.sh
$ make menuconfig

# 如果是要进入 arm64 容器
$ TARGET_ARCH=aarch64 ./scripts/buildroot-run.sh

# 然后修改完配置后保存到容器里面的 /tmp/config 
# 回到容器外, 用 docker cp 把对应的配置拷贝主来
$ DOCKER_BUILDROOT_id=$(docker ps | grep buildroot | awk '{print $1}')
# 覆盖当前的x86_64配置
# 如果是 arm64 的配置则在 ./rootfs/buildroot_conf/rootfs-aarch64.2021.08.2-0.conf
$ docker cp $DOCKER_BUILDROOT_id:/tmp/config rootfs/buildroot_conf/rootfs-x86_64.2021.08.2-0.conf

# 执行 git diff 查看更改
$ git diff
```

### Bundle 所有文件

把编译好的 rootfs ，kernel 和自定义的脚本以及二进制工具捆绑到一块。

如果本地没有内核，先使用下面命令下载内核：

```bash
$ make download-kernel-amd64-6-deb
$ make download-kernel-arm6-deb

$ ls linux-image-6
linux-image-6.1.0-13-amd64_6.1.55-1_amd64.deb
linux-image-6.1.0-13-arm64_6.1.55-1_arm64.deb
```

然后执行下面的命令进行 bundle：

```bash
# bundle x86_64 物理机 pxe 启动的 initramfs
$ make docker-bundle

# bundle arm64 物理机 pxe 启动的 initramfs
$ make docker-bundle-arm64

# bundle x86_64 和arm64 轻量虚拟机的 initramfs
$ make docker-bundle-vm
```

生成的文件会在 ./output_bundle* 目录，结构如下：

- output_bundle: x86_64 物理机 pxe 启动
- output_bundle_vm: x86_64 轻量级虚拟机启动
- output_bundle_arm64: aarch64 物理机 pxe 启动
- output_bundle_arm64_vm: aarch64 轻量级虚拟机启动

```bash
$ ls -alh output_bundle*/initramfs
-rw-r--r-- 1 root root 71M Dec 14 14:03 output_bundle/initramfs
-rw-r--r-- 1 root root 69M Dec 14 13:19 output_bundle_arm64/initramfs
-rw-r--r-- 1 root root 43M Dec 14 13:37 output_bundle_arm64_vm/initramfs
-rw-r--r-- 1 root root 45M Dec 14 13:36 output_bundle_vm/initramfs
```

### 将 initramfs 做成 yunionos 容器镜像

```bash
# 给物理机的镜像
$ make docker-yunionos-image

# 给虚拟机的镜像
$ make docker-yunionos-image-vm
```

### 将 bundle 的文件做成 RPM

```bash
$ make docker-make-rpm

$ ls output_bundle/x86_64/
baremetal-pxerom-1.1.0-21060312.x86_64.rpm
```

### 更新 pxelinux 固件

pxelinux 目录下面是从 syslinux 拷贝过来的 pxe 启动固件，可以使用以下的命令更新：

```bash
$ make pxelinux-update
```
