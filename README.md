标签：UIO

[TOC]

# SuperIO部署指南

## 1 简介

SuperIO系统软件主要包括：

* vGPU中间件：提供了通过网络(支持TCP/IP与InfiniBand)对远程/非本地NVIDIA GPU的无缝访问。

* u2Cache缓存系统：内存+SSD缓存系统，支持Memcache文本接口，并通过RDMA与SPDK技术极大的降低了访问延迟。

## 2 准备

验证当前系统是否安装了NVIDIA CUDA GPU、Mellanox InfiniBand HCA以及Memblaze Pblaze SSD：

    lspci | grep -i nvidia
    lspci | grep -i mellanox
    lspci | grep -i 1c5f

可通过`sudo update-pciids`来更细系统的PCI硬件数据库。

安装合适的内核开发库与头文件：

    sudo yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r) (RHEL/CentOS)
    sudo apt-get install linux-headers-$(uname -r) (Ubuntu)

安装编译工具链：

    sudo yum groupinstall "Development Tools" (RHEL/CentOS)
    sudo apt-get install build-essential (Ubuntu)

RHEL/CentOS下，可通过SCL安装较新版本的软件包：

    sudo yum install centos-release-scl
    sudo yum install scl-utils scl-utils-build
    sudo yum --disablerepo="*" --enablerepo="scl" list available

比如：

    sudo yum install devtoolset-4-gcc devtoolset-4-gcc-c++
    scl enable devtoolset-4 bash

RHEL/CentOS下，若要使用ISO镜像作为`yum`安装源，应首先挂载镜像：

    sudo mount -t iso9660 -o loop,ro /path/to/image.iso /mount/point

并于`/etc/yum.repos.d`下创建配置文件，比如`CentOS-ISO.repo`：

    [c6-iso]
    name=CentOS-$releasever - ISO
    baseurl=file:///mount/point/
    enabled=0
    gpgcheck=1
    gpgkey=file:///mount/point/RPM-GPG-KEY

清空`yum`缓存：

    sudo yum clean all

然后即可通过ISO镜像源安装软件包：

    yum --disablerepo=\* --enablerepo=c6-iso ...

若使用NFS共享目录，CentOS-6下首先于服务端安装NFS与RPC：

    sudo yum install nfs-utils rpcbind

并设置`/etc/exports`，比如：

    /dir/to/be/nfs/mounted IPADDR/PREFIX(insecure,rw,async,no_root_squash)

然后启动NFS与RPC服务：

    sudo service rpcbind start
    sudo service nfs start

之后即可于客户端挂载NFS目录了：

    sudo showmount -e NFS_SERVER
    sudo mount -t nfs NFS_SERVER:/dir/to/be/nfs/mounted /local/mount/point

建议关闭SELinux，编辑`/etc/selinux/config`：

    SELINUX=disabled

并重启。

若要运行时临时关闭SELinux：

    sudo setenforce 0

建议关闭防火墙：

    sudo service iptables stop
    sudo chkconfig iptables off

## 3 CUDA部署

### 3.1 安装GPU驱动

安装显示驱动前，应首先禁用Nouveau驱动。判断Nouveau是否已加载：

    lsmod | grep -i nouveau

创建文件`/etc/modprobe.d/blacklist-nouveau.conf`：

    blacklist nouveau
    options nouveau modeset=0

然后重新生成Initramfs：

    sudo dracut -f (RHEL/CentOS)
    sudo update-initramfs -u (Ubuntu)

如若已安装过GPU驱动，建议首先卸载旧版：

    sudo /usr/bin/nvidia-uninstall

可通过[NVIDIA官网](https://developer.nvidia.com/cuda-downloads)下载CUDA安装包，下载后建议先进行MD5校验，比如：

    $ md5sum cuda_7.5.18_linux.run
    4b3bcecf0dfc35928a0898793cf3e4c6  cuda_7.5.18_linux.run

执行安装：

    sudo sh cuda_7.5.18_linux.run

或者仅解压：

    sh cuda_7.5.18_linux.run --extract=/absolute/path/to/extract/

解压后得到`cuda-linux64-rel-7.5.18-19867135.run`(工具包)、`cuda-samples-linux-7.5.18-19867135.run`(示例)以及`NVIDIA-Linux-x86_64-352.39.run`(驱动)三个文件，可通过`sh`分别执行安装或使用`--extract-only`、`-x`或`--tar mxvf`选项对其进一步解压。

安装驱动前应先退出图形环境，进入TTY后(比如按下`Ctrl+Alt+F2`)：

    sudo /sbin/init 3

然后执行驱动`run`文件，根据提示逐步完成内核驱动的安装。

安装完成后查看驱动版本：

    $ modinfo nvidia
    filename:       /lib/modules/2.6.32-504.el6.x86_64/kernel/drivers/video/nvidia.ko
    alias:          char-major-195-*
    version:        352.39
    supported:      external
    license:        NVIDIA
    ... ...

或：

    $ cat /proc/driver/nvidia/version
    NVRM version: NVIDIA UNIX x86_64 Kernel Module  352.39  Fri Aug 14 18:09:10 PDT 2015
    GCC version:  gcc version 4.4.7 20120313 (Red Hat 4.4.7-11) (GCC)

### 3.2 安装CUDA工具包

CUDA工具包的安装比较简单，执行工具包`run`文件后根据提示逐步执行即可完成安装。

工具包需对环境进行一定的配置：

* `PATH`包含`/path/to/cuda/install/bin`；

* `LD_LIBRARY_PATH`包含`/path/to/cuda/install/lib64:/path/to/cuda/install/lib`，或者将上述两个目录加入`/etc/ld.so.conf/cuda-x.y-x86_64.conf`并执行`sudo ldconfig -v`。

配置完成后可查看工具包版本：

    $ nvcc --version
    nvcc: NVIDIA (R) Cuda compiler driver
    Copyright (c) 2005-2012 NVIDIA Corporation
    Built on Thu_Apr__5_00:24:31_PDT_2012
    Cuda compilation tools, release 4.2, V0.2.1221

### 3.3 安装CUDA示例

CUDA示例的安装比较简单，执行示例`run`文件后根据提示逐步执行即可完成安装。

示例安装完成后，可通过编译并运行`deviceQuery`、`bandwidthTest`等以验证CUDA环境是否配置妥当，比如：

    $ ./deviceQuery 
    CUDA Device Query (Runtime API) version (CUDART static linking)
    Detected 1 CUDA Capable device(s)
    Device 0: "Tesla K40m"
      CUDA Driver Version / Runtime Version          7.5 / 4.2
      CUDA Capability Major/Minor version number:    3.5
      Total amount of global memory:                 11520 MBytes (12079136768 bytes)
      (15) Multiprocessors x (192) CUDA Cores/MP:    2880 CUDA Cores
      GPU Clock rate:                                745 MHz (0.75 GHz)
      Memory Clock rate:                             3004 Mhz
      Memory Bus Width:                              384-bit
      L2 Cache Size:                                 1572864 bytes
    ... ...
    deviceQuery, CUDA Driver = CUDART, CUDA Driver Version = 7.5, CUDA Runtime Version = 4.2, NumDevs = 1, Device0 = Tesla K40m

如要编译GL相关代码，需安装GLUT库：

    sudo yum install freeglut-devel (RHEL/CentOS)
    sudo apt-get install freeglut3-dev (Ubuntu)

如要编译X相关代码，需安装：

    sudo yum install libXi-devel libXmu-devel

## 4 OFED部署

### 4.1 安装InBox OFED

通过官方软件源安装OFED软件包是一种比较简便的安装方法，比如RHEL/CentOS下：

    sudo yum groupinstall "InfiniBand Support"

若要安装可选包：

    sudo yum --setopt=group_package_types=optional groupinstall "InfiniBand Support"

其中，

* `rdma`/`openibd`负责RDMA栈的内核模块的加载与初始化，若后期手动安装，应重建Initramfs：`sudo dracut -f`；

* `libibverbs`是核心用户空间库，实现了Verbs协议；

* `libmthca`、`libmlx4`等则是用户级驱动，与相应内核模块密切依赖；

* `opensm`负责管理子网，当前网络没有活动的子网管理器时，仅启动一个子网管理器即可；

* `libibcm`与`librdmacm`用于简化IB主机之间连接的初始化与建立；

* `libibverbs-utils`、`infiniband-diags`、`ibutils`等提供了基础的查询、调试工具；

* `perftest`、`qperf`提供了性能测试工具。

安装完成后启动`rdma`/`openibd`服务：

    sudo /etc/init.d/rdma start
    sudo chkconfig rdma on

`rdma`服务配置文件为`/etc/rdma/rdma.conf`，`openibd`服务配置文件为`/etc/ofed/openib.conf`或`/etc/infiniband/openib.conf`。

于选定的节点启用子网管理服务`opensmd`：

    sudo /etc/init.d/opensmd start
    sudo chkconfig opensmd on

`opensm`服务配置文件为`/etc/rdma/opensm.conf`或`/etc/ofed/opensm.conf`或`/etc/infiniband/opensm.conf`。

验证内核驱动：

    lsmod | grep -i ib
    lsmod | grep -i rdma

或者：

    sudo service rdma status
    sudo service openibd status

确保底层硬件驱动(比如`mlx4_core`、`mlx4_ib`)与中间层核心组件(比如`ib_core`、`ib_uverbs`)已加载。

建议提高非root用户可锁定(Pinned)内存的大小，编辑配置文件`/etc/security/limits.conf`或`/etc/security/limits.d/rdma.conf`，加入如下两行：

    * soft memlock unlimited
    * hard memlock unlimited

### 4.2 安装社区版OFED或MLNX OFED

也可从[OpenFabrics网站](https://www.openfabrics.org/downloads/OFED/)下载社区版OFED安装包解压后安装，或通过[Mellanox官网](http://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux_sw_drivers)下载安装包。

安装MLNX OFED时，如果内核版本不符，可通过`--add-kernel-support`添加当前内核的支持；此种方式需要安装额外软件包依赖：

    sudo yum install createrepo libnl tcl numactl pciutils tcsh tk python-devel lsof

### 4.3 IPoIB配置

IPoIB即基于InfiniBand模拟IP层，对iWARP和RoCE/IBoE而言，由于其本身即是IP网络，因而无需再支持IPoIB。IPoIB支持两种模式：`Datagram`模式基于不可靠、不连接的QP，而`Connected`模式则基于可靠的、连接的QP。

配置IPoIB，首先验证内核中的IPoIB模块：

    lsmod | grep -i ipoib

确保`ib_ipoib`模块已加载；若需手动加载/卸载：

    sudo modprobe ib_ipoib (加载)
    sudo modprobe -r ib_ipoib (卸载)

当IPoIB内核模块顺利加载后，IB设备的每一个端口都对应到一个网络接口；IPoIB接口名称一般以`ib`开头，比如：

    $ ip a
    ... ...
    4: ib0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 4096 qdisc pfifo_fast state DOWN qlen 256
        link/infiniband 80:00:00:48:fe:80:00:00:00:00:00:00:e4:1d:2d:03:00:77:40:01 brd 00:ff:ff:ff:ff:12:40:1b:ff:ff:00:00:00:00:00:00:ff:ff:ff:ff
    ... ...

可对该网口进行配置，比如编辑配置文件`/etc/sysconfig/network-scripts/ifcfg-ib0`：

    DEVICE=ib0
    TYPE=InfiniBand
    ONBOOT=yes
    NM_CONTROLLED=yes
    BOOTPROTO=none
    HWADDR=80:00:02:08:FE:80:00:00:00:00:00:00:7C:FE:90:03:00:99:2F:51
    CONNECTED_MODE=no
    IPADDR=10.18.130.175
    PREFIX=16
    DEFROUTE=yes
    IPV4_FAILURE_FETAL=yes
    IPV6INIT=no
    NAME="System ib0"

完成后重启`network`服务以使配置生效。

### 4.4 基本测试
 
可通过`ibv_devices`、`ibv_devinfo`、`ibstat`、`ibstatus`等工具查看InfiniBand设备及连接的状态，比如：

    $ sudo ibstatus
    Infiniband device 'mlx4_0' port 1 status:
            default gid:     fe80:0000:0000:0000:e41d:2d03:0077:4001
            base lid:        0x1
            sm lid:          0x2
            state:           4: ACTIVE
            phys state:      5: LinkUp
            rate:            56 Gb/sec (4X FDR)
            link_layer:      InfiniBand

可使用`ibping`验证InfiniBand网络的连通性(具体参数(设备、端口、本地iD等)设定需根据具体设备信息而定)：

* 服务端：`sudo ibping -S -C mlx4_0 -P 1`；

* 客户端：`sudo ibping -c 1024 -f -C mlx4_0 -P 1 -L 1`。

可通过`ib_***`测试InfiniBand网络的性能，比如测试RDMA写延迟，

* 服务端：`sudo ib_write_lat -a`；

* 客户端：`sudo ib_write_lat -a [SERVER-HOST]`。

如若测试程序提示CPU主频冲突，可执行如下脚本将强制CPU工作在标准主频：

    for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -f $CPUFREQ ] || continue; echo -n performance | tee $CPUFREQ; done

Linux 3.9及以上内核可通过`intel_pstate`控制处理器主频，系统接口为：

    /sys/devices/system/cpu/intel_pstate/

可通过`rping`、`udaddy`、`ucmatose`、`rdma_server`/`rdma_client`等验证RDMA_CM的可用性，比如

* 服务端：`ucmatos`；

* 客户端：`ucmatos -s $SERVER_IP`。

## 5 MVAPICH2部署

MVAPICH2源码包可从[俄亥俄州立大学官网](http://mvapich.cse.ohio-state.edu/downloads/)下载，解压后执行如下步骤进行编译安装：

    ./configure --prefix=/path/to/install/mvapich2
    make
    make install

可通过运行示例的`cpi`程序验证安装：

    /path/to/mvapich2/bin/mpirun_rsh --hostfile hosts -np 2 /path/to/mvapich2-2.1/examples/cpi

## 6 Ruby部署

通过包管理器安装即可，比如RHEL/CentOS下：

    sudo yum install ruby rubygems

为保证后续的dscuda与vGPU能够正常编译，应保证`ruby`安装或链接至`/usr/bin/ruby`。

## 7 dscuda编译与使用

以DS-CUDA 2.5为例介绍其编译与使用。

编译时需要的环境变量

* `CUDAPATH`：CUDA工具包目录；

* `CUDASDKPATH`：CUDA SDK目录。

进入`src`目录执行`make`即可编译生成DS-CUDA服务端。

启动服务端需要的环境变量

* `DSCUDA_SVRPATH`：比如`/var/tmp`；

* `LD_LIBRARY_PATH`：包含CUDA运行时库`$CUDAPATH/lib64`。

运行`src/dscudad`即可启动DS-CUDA值守进程。

运行客户端需要的环境变量

* `DSCUDA_SVRPATH`：指向编译生成的`svr`映像，比如`userapp_ibv.svr`所在的目录；

* `DSCUDA_SERVER`：服务端主机名或IP地址，若要使用多个GPU设备，则按`"server0:0 server0:1 server1:0 ..."`的格式进行设置；

* `DSCUDA_DAEMON`：设为1即可；

* `LD_LIBRARY_PATH`：包含DS-CUDA的运行时库`$DSCUDA_PATH/lib`。

`sample`目录下提供了典型的客户端示例，进入相应目录下`make`即可编译。

## 8 vGPU使用与编译

### 8.1 vGPU使用

版本`20160419`的VGPU发布版包含了可执行二进制码，可直接运行、测试。

服务端需设定如下变量：

* `DSCUDA_PATH`：该版本VGPU基于DS-CUDA 1.2.7，因而该路径应指向`1.2.7`版本的DS-CUDA所在目录；

* `VGPU_REMOTECALL`：设为`ibv`；

* `LD_LIBRARY_PATH`：包含CUDA运行时库；由于该版本的VGPU基于CUDA 5.0，因而应包含`5.0`版本的CUDA运行时路径。

配置完成后执行`src/VGPUSvr`即可启用VGPU服务端。若要提供对多GPU设备的远程访问，则应启动多个VGPU服务端实例：

    VGPUSvr -s 0 -d 0
    VGPUSvr -s 1 -d 1
    ... ...

`-s`设定服务端iD，`-d`设定设备iD。

客户端需设定如下变量：

* `DSCUDA_PATH`与`VGPU_REMOTECALL`：同上；

* `VGPU_PATH`：VGPU所在目录；

* `VGPU_SERVER`：VGPU服务端IPoIB地址，如若是多设备多服务端，则应按照`"server0:0 server0:1 server1:0 ..."`的格式进行设置；

* `LD_LIBRARY_PATH`：包含VGPU库路径、CUDA运行时库路径以及MPI运行时库路径。

配置完成后可执行`sample`目录下的示例客户端进行验证与测试；对于多进程共享GPU，可通过MPI等框架等实现，VGPU提供的示例即基于MPI，可使用`mpirun`等工具启动多进程进行GPU共享测试。

### 8.2 vGPU编译

需设置`CUDAPATH`与`CUDASDKPATH`两个环境变量，另外由于示例使用了MPI，还应配置MPI相关环境或路径。

vGPU解压于`src`目录下执行`make`即可，生成以下文件：

* `VGPUSvr`：vGPU服务端，

* `libVGPUIbv.a`与`libVGPURpc.a`：vGPU客户端静态库，

* `libcudart.so.3`：vGPU客户端运行时。

示例代码的编译进入`sample`下的相应目录执行`make`即可完成。

## 9 Memblaze设备管理

可以使用官方管理工具`nvmemgr`对Memblaze设备进行管理；`nvmemgr`从[官方网站](http://www.memblaze.com/cn/zcyxz/zlxz.html)下载后解压编译即可。

进行性能测试前，应将设备置于最高电源模式(25W)下：

    sudo nvmemgr setfeature --ctrl nvme0 --featureid 198 --value 0

为获得出厂性能，可尝试对设备执行安全擦除(SE)：

    sudo nvmemgr formatnvm --ns nvme0n1 --lbaformat 0 --secureerase 1

可使用`parted`对设备进行分区，比如：

    sudo parted /dev/nvme0n1 mklabel msdos
    sudo parted --align optimal /dev/nvme0n1 mkpart primary 0% 100%
    sudo mkfs.ext4 /dev/nvme0n1p1

然后即可通过`mount`命令进行挂载并访问。
