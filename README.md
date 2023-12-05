Cloudpods PXE／ISO ROM scripts
===============================

## 使用方法

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
# x86_64
$ ls ./output/images/rootfs.tar

# arm64
$ ls ./output_arm64/images
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
$ make download-kernel-rpm

$ ls kernel*
kernel-ml-5.12.9-1.el7.elrepo.x86_64.rpm
```

然后执行下面的命令进行 bundle：

```bash
# bundle x86_64
$ make docker-bundle
# bundle arm64
$ make docker-bundle-arm64

# 或者执行 docker-bundle-all
$ make docker-bundle-all

# 生成的文件会在 ./output_bundle 和 ./output_bundle_arm64
$ ls output_bundle
baremetal_prepare         bootx64.efi  intermediate  ldlinux.c32  libcom32.c32  menu.c32
baremetal_prepare.tar.gz  chain.c32    isolinux.bin  ldlinux.e32  libutil.c32   pxelinux.0
bootia32.efi              initramfs    kernel        ldlinux.e64  lpxelinux.0
```

### 将 bundle 文件做成 yunionos docker image

```bash
$ YUNIONOS_VERSION=test-version-20231205.2 make docker-yunionos-image
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
