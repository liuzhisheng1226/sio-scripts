#!/usr/bin/env bash
# demonstration of doing a full NVMe SSD benchmarking through the kernel.
# this may take a couple of days and nights.

# sequentially fill the drive several times
for i in {0..3}
do
	sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M oflag=direct
	sleep 4
done
# then benchmark the bandwidth performance
for i in {0..7}
do
	sudo numactl --cpunodebind=1 --membind=1 fio ./raw_std_bw.fio      --output=./res/raw/bw_$i.txt
	sleep 4
done

# randomly write the drive so the performance enters the steady state
for i in 0
do
	sudo numactl --cpunodebind=1 --membind=1 fio ./raw_std_steady.fio  --output=./res/raw/steady.txt
	sleep 4
done
# then benchmark the IOPS and latency performance
for i in {0..7}
do
	sudo numactl --cpunodebind=1 --membind=1 fio ./raw_std_iops_4k.fio --output=./res/raw/iops_4k_$i.txt
	sleep 4
	sudo numactl --cpunodebind=1 --membind=1 fio ./raw_std_iops_8k.fio --output=./res/raw/iops_8k_$i.txt
	sleep 4
	sudo numactl --cpunodebind=1 --membind=1 fio ./raw_std_lat.fio     --output=./res/raw/lat_$i.txt
	sleep 4
done
