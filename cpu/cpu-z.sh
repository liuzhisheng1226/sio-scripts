#!/usr/bin/env bash
# Query and display some of the basic system information, including:
# * CPU model, cores and sockets
# * Memory size
# * GPU model (NVIDIA)
# * InfiniBand HCAs (Mellanox)
# * PCIe SSD controllors (Memblaze)
# * SCSI/SATA drive model and capacity
# * Linux distro
# * kernel version
#   display a WARNING if kernel-devel or kernel-headers not installed
# * gcc version
# * CUDA driver version

set -e

# Processor(s)
#echo -e "\033[1;37;41m Processor(s) \033[0m"
echo -e "\033[1mProcessor(s)\033[0m"
while IFS='' read -r line || [[ -n "$line" ]]; do
	if   echo $line | grep -i -q "model name";  then
		CPUNAME=$(echo $line | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//' | tr -s ' ')
	elif echo $line | grep -i -q "physical id"; then
		CPUNUM=$( echo $line | cut -d ' ' -f 4)
	elif echo $line | grep -i -q "cpu cores";   then
		CORENUM=$(echo $line | cut -d ' ' -f 4)
	fi
done < <(grep -i -e "model name" -e "physical id" -e "cpu cores" /proc/cpuinfo | tail -n 3)
echo -e -n '\t'
echo "$((CPUNUM+1))-Socket(s) $CPUNAME, each $CORENUM Cores"

# Memory
echo -e "\033[1mSystem Memory\033[0m"
MEMSIZE=$(grep -i "memtotal" /proc/meminfo | tr -dc '0-9')
echo -e -n '\t'
echo "$((MEMSIZE/1024)) MiB"

# NorthBridge I/Os
if command -v lspci >/dev/null 2>&1; then
	echo -e "\033[1mGPU Accelerator(s)\033[0m"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//'
	done < <(lspci | grep -i "nvidia" || echo "NONE NVIDIA GPU(s) detected!")

	echo -e "\033[1mInfiniBand HCA(s)\033[0m"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//'
	done < <(lspci | grep -i "mellanox" || echo "NONE Mellanox HCA(s) detected!")

	echo -e "\033[1mPCIe SSD Controllor(s)\033[0m"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -c 9-
	done < <(lspci | grep -i "1c5f" || echo "@ @ @ @ NONE Memblaze SSD(s) detected!")
else
	echo >&2 "ERROR: lspci required! Please yum install pciutils!"
fi

# SouthBridge Drive(s)
if command -v lsblk >/dev/null 2>&1; then
	echo -e "\033[1mSCSI/SATA HDD(s)/SSD(s)\033[0m"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ' ' -f 3-
		#echo $line | cut -d ' ' -f 3- | sed -r 's/ ([^ ]*)$/, \1/'
	done < <(lsblk -o TYPE,NAME,MODEL,SIZE | grep -i "disk" | grep -i "sd" || echo -e "@ @ NONE HDD(s) detected!")
else
	echo >&2 "ERROR: lsblk required! Please yum install util-linux-ng!"
fi

# Operating System
echo -e "\033[1mOS Distro\033[0m"
if [ -f /etc/centos-release ]; then
	echo -e -n '\t'
	echo $(cat /etc/centos-release)
elif [ -f /etc/redhat-release ]; then
	echo -e -n '\t'
	echo $(cat /etc/redhat-release)
elif [ -f /etc/lsb-release ]; then
	echo -e -n '\t'
	echo $(cat /etc/lsb-release | grep -i description | cut -d '"' -f 2)
else
	echo -e -n '\t'
	echo "Unrecognized Linux Distro ..."
fi

# Kernel
echo -e "\033[1mOS Kernel\033[0m"
echo -e -n '\t'
echo $(uname -sr)
if command -v rpm >/dev/null 2>&1; then
	rpm -q kernel-devel-$(uname -r)      >/dev/null 2>&1 || \
	rpm -q kernel-lt-devel-$(uname -r)   >/dev/null 2>&1 || \
	{ echo -e -n '\t'; echo >&2 "WARNING: failed to find package kernel-devel for current kernel ...";   }
	rpm -q kernel-headers-$(uname -r)    >/dev/null 2>&1 || \
	rpm -q kernel-lt-headers-$(uname -r) >/dev/null 2>&1 || \
	{ echo -e -n '\t'; echo >&2 "WARNING: failed to find package kernel-headers for current kernel ..."; }
elif command -v dpkg >/dev/null 2>&1; then
	dpkg -l linux-headers-$(uname -r)    >/dev/null 2>&1 || \
	{ echo -e -n '\t'; echo >&2 "WARNING: failed to find package linux-headers for current kernel ...";  }
fi

# GCC
if command -v gcc >/dev/null 2>&1; then
	echo -e "\033[1mGCC Compiler\033[0m"
	echo -e -n '\t'
	echo $(gcc --version | head -n 1 | cut -c 4-)
else
	echo "GCC not installed! Please yum install gcc gcc-c++!"
fi

# CUDA driver
if [ -e /proc/driver/nvidia/version ]; then
	echo -e "\033[1mCUDA Driver\033[0m"
	echo -e -n '\t'
	echo $(head -n 1 /proc/driver/nvidia/version | tr -s ' ' | cut -d ' ' -f 3-8)
fi
