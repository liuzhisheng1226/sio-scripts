#!/usr/bin/env bash
# Check and display some of the baisc system information.

set -e

# Processor(s)
echo "Processor(s):"
while IFS='' read -r line || [[ -n "$line" ]]; do
	if   echo $line | grep -i -q "model name";  then
		CPUNAME=$(echo $line | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//' | tr -s ' ')
	elif echo $line | grep -i -q "physical id"; then
		CPUNUM=$( echo $line | cut -d ' ' -f 4)
	elif echo $line | grep -i -q "cpu cores";   then
		CORENUM=$(echo $line | cut -d ' ' -f 4)
	fi
done < <(grep -i -e "model name" -e "physical id" -e "cpu cores" /proc/cpuinfo | tail -n 3)
for (( i=0; i<=$CPUNUM; i++))
do
	echo -e -n '\t'
	echo "Socket-$i: $CPUNAME, $CORENUM Cores"
done

# Memory
echo "System Memory:"
	MEMSIZE=$(grep -i "memtotal" /proc/meminfo | tr -dc '0-9')
	echo -e -n '\t'
	echo "$((MEMSIZE/1024)) MiB"

# NorthBridge I/Os
if command -v lspci >/dev/null 2>&1; then
	echo "GPU Accelerator(s):"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//'
	done < <(lspci | grep -i "nvidia" || echo "NONE NVIDIA GPU(s) detected!")

	echo "InfiniBand HCA(s):"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//'
	done < <(lspci | grep -i "mellanox" || echo "NONE Mellanox HCA(s) detected!")

	echo "PCIe SSD Controllor(s):"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -c 9-
	done < <(lspci | grep -i "1c5f" || echo "@@@@@@@@NONE Memblaze SSD(s) detected!")
else
	echo "lspci required! please yum install pciutils!"
fi

# SouthBridge Drive(s)
if command -v lsblk >/dev/null 2>&1; then
	echo "SCSI/SATA HDD(s)/SSD(s):"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo -e -n '\t'
		echo $line | cut -d ' ' -f 3-
		#echo $line | cut -d ' ' -f 3- | sed -r 's/ ([^ ]*)$/, \1/'
	done < <(lsblk -o TYPE,NAME,MODEL,SIZE | grep -i "disk" | grep -i "sd" || echo -e "@ @ NONE HDD(s) detected!")
else
	echo "lsblk required! please yum install util-linux-ng!"
fi

# Operating System
echo "OS Distribution:"
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
	echo "Unrecognized Distro ..."
fi

# Kernel
echo "OS Kernel:"
	echo -e -n '\t'
	echo $(uname -sr)

# GCC
if command -v gcc >/dev/null 2>&1; then
	echo "GCC compiler:"
	echo -e -n '\t'
	echo $(gcc --version | grep -i gcc | cut -c 4-)
else
	echo "gcc not installed! please yum install gcc gcc-c++"
fi
