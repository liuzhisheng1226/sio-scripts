#!/usr/bin/env bash
# demonstration of doing a full NVMe SSD benchmarking through the kernel.
# this may take a couple of days and nights.

# set up fio executable and the working directory
FIO=fio
[[ -z $1 ]] || FIO=$1
JOBDIR=.
[[ -z $2 ]] || JOBDIR=$2
RESDIR=$JOBDIR/res/kernel
[[ -d $RESDIR ]] || mkdir -p $RESDIR

# sequentially fill the drive several times
for each in {0..3}
do
	dd if=/dev/zero of=/dev/nvme0n1 bs=1M oflag=direct
	sleep 4
done
# then benchmark the bandwidth performance
for i in {0..7}
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_bw.fio --output=$RESDIR/bw_$i.txt
	$FIO $JOBDIR/raw_std_bw.fio --output=$RESDIR/bw_$i.txt
	sleep 4
done

# randomly write the drive so the performance enters the steady state
for once in 0
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_steady.fio --output=$RESDIR/steady.txt
	$FIO $JOBDIR/raw_std_steady.fio --output=$RESDIR/steady.txt
	sleep 4
done
# then benchmark the IOPS and latency performance
for i in {0..7}
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_iops_4k.fio --output=$RESDIR/iops_4k_$i.txt
	$FIO $JOBDIR/raw_std_iops_4k.fio --output=$RESDIR/iops_4k_$i.txt
	sleep 4
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_iops_8k.fio --output=$RESDIR/iops_8k_$i.txt
	$FIO $JOBDIR/raw_std_iops_8k.fio --output=$RESDIR/iops_8k_$i.txt
	sleep 4
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_lat.fio     --output=$RESDIR/lat_$i.txt
	$FIO $JOBDIR/raw_std_lat.fio     --output=$RESDIR/lat_$i.txt
	sleep 4
done
