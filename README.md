标签：UIO

[TOC]

# VIO部署指南

## 1 简介

VIO系统软件主要包括：

* vGPU中间件：提供了通过网络(支持TCP/IP与InfiniBand)对远程/非本地NVIDIA GPU的无缝访问。

* u2Cache缓存系统：内存+SSD缓存系统，支持Memcache文本接口，并利用RDMA与SPDK技术极大的降低了访问延迟。

## 2 准备

验证当前系统是否安装了NVIDIA CUDA GPU、Mellanox InfiniBand HCA以及Memblaze Pblaze SSD：

    lspci | grep -i nvidia
    lspci | grep -i mellanox
    lspci | grep -i 1c5f

可通过`sudo update-pciids`来更细系统的PCI硬件数据库。

部署VIO之前需安装合适的内核开发库与头文件：

    sudo yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r) (RHEL/CentOS)

若要安装更新版本的内核，可使用[elrepo](http://elrepo.org/)提供的源：

    sudo rpm -Uvh http://www.elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm
    sudo yum install yum-plugin-fastestmirror

然后即可通过`yum`安装：

    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-lt
    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-lt-devel
    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-lt-headers

或

    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-ml
    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-ml-devel
    sudo yum --disablerepo=\* --enablerepo=elrepo install kernel-ml-headers

安装编译工具链：

    sudo yum groupinstall "Development Tools" (RHEL/CentOS)

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

    yum --disablerepo=\* --enablerepo=c6-iso install ...

若使用NFS共享目录，CentOS-6下首先于服务端安装NFS与RPC：

    sudo yum install nfs-utils rpcbind

并配置`/etc/exports`，格式如下：

    /dir/to/be/nfs/mounted IPADDR/PREFIX(OPTIONS)

比如：

    /root/super-io *(insecure,rw,async,no_root_squash)

然后启动NFS与RPC服务：

    sudo service rpcbind start
    sudo service nfs start

之后即可于客户端挂载NFS目录了：

    sudo mount -t nfs $NFS_SERVER:/dir/to/be/nfs/mounted /local/mount/point

建议关闭SELinux，配置`/etc/selinux/config`：

    SELINUX=disabled

并重启系统；若要运行时临时关闭SELinux：

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

如若已安装过GPU驱动，建议首先卸载旧版：

    sudo /usr/bin/nvidia-uninstall

可通过[NVIDIA官网](https://developer.nvidia.com/cuda-downloads)下载CUDA安装包，下载后建议先进行MD5校验，比如：

    $ md5sum cuda_7.5.18_linux.run
    4b3bcecf0dfc35928a0898793cf3e4c6  cuda_7.5.18_linux.run

执行安装：

    sudo sh cuda_7.5.18_linux.run

或者仅解压：

    sh cuda_7.5.18_linux.run --extract=/absolute/path/to/extract/

解压后得到`cuda-linux64-rel-7.5.18-19867135.run`(工具包)、`cuda-samples-linux-7.5.18-19867135.run`(示例)以及`NVIDIA-Linux-x86_64-352.39.run`(驱动)三个文件，可通过`sh`分别执行安装或使用`--extract-only`、`-x`或`--tar mxvf`等选项对其进一步解压。

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

如要编译X与GL相关代码，需安装：

    sudo yum install freeglut-devel libXi-devel libXmu-devel (RHEL/CentOS)
    sudo apt-get install freeglut3-dev (Ubuntu)

## 4 OFED部署

### 4.1 安装InBox OFED

通过OS发行版官方软件源安装OFED软件包是一种比较简便的安装方法，比如RHEL/CentOS下：

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

### 4.2 安装Community OFED或Mellanox OFED

也可从[OpenFabrics网站](https://www.openfabrics.org/downloads/OFED/)下载社区版OFED安装包解压后安装，或通过[Mellanox官网](http://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux_sw_drivers)下载安装包。

安装MLNX OFED时，如果内核版本不符，可通过`--add-kernel-support`添加当前内核的支持；此种方式需要安装额外软件包依赖：

    sudo yum install createrepo libnl tcl numactl pciutils tcsh tk python-devel lsof

### 4.3 IPoIB配置

IPoIB即基于InfiniBand模拟IP层，对iWARP和RoCE/IBoE而言，由于其本身即是IP网络，因而无需再支持IPoIB。IPoIB支持两种模式：`Datagram`模式基于不可靠、不连接的QP，而`Connected`模式则基于可靠的、连接的QP。

配置IPoIB，首先验证内核中的IPoIB模块：

    lsmod | grep -i ipoib

确保`ib_ipoib`模块已加载；若需手动加载/卸载：

    sudo modprobe ib_ipoib
    sudo modprobe -r ib_ipoib

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

可通过`ib_***`测试InfiniBand网络的性能，比如测试RDMA写延迟：

* 服务端：`sudo ib_write_lat -a`；

* 客户端：`sudo ib_write_lat -a $SERVER-HOST`。

再比如测试InfiniBand通信带宽：

* 服务端：`sudo ib_send_lat -a`；

* 客户端：`sudo ib_send_lat -a $SERVER-HOST`。

如若测试程序提示CPU主频冲突，可执行如下脚本将强制CPU工作在标准主频：

    for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -f $CPUFREQ ] || continue; echo -n performance | tee $CPUFREQ; done

Linux 3.9及以上内核可通过`intel_pstate`控制处理器主频，系统接口为：

    /sys/devices/system/cpu/intel_pstate/

可通过`rping`、`udaddy`、`ucmatose`、`rdma_server`/`rdma_client`等验证RDMA_CM的可用性，比如：

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

编译时需要的环境变量：

* `CUDAPATH`：CUDA工具包目录；

* `CUDASDKPATH`：CUDA SDK目录。

进入`src`目录执行`make`即可编译生成DS-CUDA服务端。

启动服务端需要的环境变量：

* `DSCUDA_SVRPATH`：比如`/var/tmp`；

* `LD_LIBRARY_PATH`：包含CUDA运行时库`$CUDAPATH/lib64`。

运行`src/dscudad`即可启动DS-CUDA值守进程。

运行客户端需要的环境变量：

* `DSCUDA_SVRPATH`：指向编译生成的`svr`映像，比如`userapp_ibv.svr`所在的目录；

* `DSCUDA_SERVER`：服务端主机名或IP地址，若要使用多个GPU设备，则按`"server0:0 server0:1 server1:0 ..."`的格式进行设置；

* `DSCUDA_DAEMON`：设为1即可；

* `LD_LIBRARY_PATH`：包含DS-CUDA的运行时库`$DSCUDA_PATH/lib`。

`sample`目录下提供了典型的客户端示例，进入相应目录下`make`即可编译。

## 8 vGPU使用与编译

### 8.1 vGPU使用

运行vGPU之前需进行环境变量的配置。服务端需设定如下变量：

* `DSCUDA_PATH`：该版本VGPU基于DS-CUDA 1.2.7，因而该路径应指向`1.2.7`版本的DS-CUDA所在目录；

* `VGPU_REMOTECALL`：设为`ibv`，采用高性能InfiniBand网络；

* `LD_LIBRARY_PATH`：包含CUDA运行时库；本版本的VGPU仅支持CUDA 4.2。

配置完成后执行`src/VGPUSvr`即可启用VGPU服务端。若要提供对多GPU设备的远程访问，则应启动多个VGPU服务端实例：

    VGPUSvr -s 0 -d 0
    VGPUSvr -s 1 -d 1
    ... ...

其中，`-s`设定服务端iD，`-d`设定设备iD。

客户端需设定如下变量：

* `DSCUDA_PATH`与`VGPU_REMOTECALL`：同上；

* `VGPU_PATH`：VGPU所在目录；

* `VGPU_SERVER`：VGPU服务端IPoIB地址，如若是多设备多服务端，则应按照`"server0:0 server0:1 server1:0 ..."`的格式进行设置；

* `LD_LIBRARY_PATH`：包含VGPU库路径、CUDA运行时库路径以及MPI运行时库路径。

### 8.2 vGPU编译

编译前需设置`CUDAPATH`与`CUDASDKPATH`两个环境变量。

于`src`目录下执行`make`即可，生成以下文件：

* `VGPUSvr`：vGPU服务端，

* `libVGPUIbv.a`与`libVGPURpc.a`：vGPU客户端静态库，

* `libcudart.so.3`：vGPU客户端运行时。

### 8.3 vGPU示例编译

vGPU示例的编译比较简单，配置完上述环境变量后执行`make`即可。目前提供如下示例：

* `vecadd`：简单的向量加实现，未采用CUDA工具函数；另采用MPI实现多进程，亦可采用其他机制。

* `bandwidth`：简单的带宽测试，未采用CUDA工具函数；VGPU客户端目前尚未支持`cudaMallocHost()`等的实现。

* `transpose`：矩阵转置，基于CUDA SDK 2.x，仅添加了MPI多进程部分的代码。

* `BlackScholes`：BS期权定价模型，基于CUDA SDK 2.x，仅添加了MPI多进程部分的代码。

## 9 Memblaze设备管理

### 9.1 PBlaze3管理

设备代码`0530`即是PBlaze3设备；PBlaze3采用忆恒创源私有协议接口，相应驱动及管理工具可从[官方网站](http://www.memblaze.com/cn/zcyxz/zlxz.html)下载安装。

驱动的编译与安装比较简单，解压源码包后执行`make`与`make install`即可。安装会把驱动文件`memcon.ko`与`memdisk.ko`拷贝到目录`/lib/modules/$(uname -r)`下，并配置`/etc/sysconfig/modules/memdisk.modules`以确保系统启动时自动加载驱动，最后将工具程序拷贝至`/usr/bin`目录下。

可使用`memmonitor`查看设备名称与序列号、软硬件版本、寿命状态、写放大等信息。

若要恢复出厂性能，可尝试对设备执行安全擦除(Secure Erase)，比如：

    sudo memtach -d /dev/memcona
    sudo memctrl -i 1145088 /dev/memcona
    sudo memtach -a /dev/memcona

首条与末条命令分别卸载、挂载设备，第二条命令参数`-i`指定安全擦除操作，`1145088`即重新分配的可用空间大小，该数值针对1.2TB容量的设备。

PBlaze3支持`High`与`Extreme`两种性能模式，为获得最佳性能，可将设备切换为`Extreme`模式：

    sudo memtach -d /dev/memcona
    sudo memctrl -s Extreme /dev/memcona
    sudo memtach -a /dev/memcona

### 9.2 PBlaze4管理

设备代码`0540`即是PBlaze4设备；PBlaze4基于标准NVMe接口，因而采用Linux内核`nvme`即可。对于低版本内核的驱动以及管理工具`nvmemgr`，同样可从官网下载安装。

为获得出厂性能，可尝试对设备执行安全擦除：

    sudo nvmemgr formatnvm --ns nvme0n1 --lbaformat 0 --secureerase 1

进行性能测试前，应将设备置于最高电源模式(25W)下：

    sudo nvmemgr setfeature --ctrl nvme0 --featureid 198 --value 0

若要创建分区及文件系统，可使用`parted`，比如：

    sudo parted /dev/nvme0n1 mklabel msdos
    sudo parted --align optimal /dev/nvme0n1 mkpart primary 0% 100%
    sudo mkfs.ext4 /dev/nvme0n1p1

然后即可通过`mount`命令进行挂载并访问。
