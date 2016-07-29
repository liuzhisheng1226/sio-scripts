#!/usr/bin/env bash
# demonstration of doing a full FS benchmarking.

# set up fio executable and the working directory
FIO=fio
[ -z $1 ] || FIO=$1
BENCHDIR=/mnt/nvme0n1p1
[ -z $2 ] || BENCHDIR=${2%/}
JOBDIR=.
[ -z $3 ] || JOBDIR=${3%/}
RESDIR=$JOBDIR/results/fs
[ -d $RESDIR ] || mkdir -p $RESDIR

# sequentially fill the filesystem several times
for each in {0..3}
do
	dd if=/dev/zero of=$BENCHDIR/fio_file bs=1M oflag=direct
	sleep 4
done
# then benchmark the bandwidth performance
for i in {0..7}
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/fs_std_bw.fio --output=$RESDIR/bw_$i.txt
	$FIO $JOBDIR/fs_std_bw.fio --output=$RESDIR/bw_$i.txt
	sleep 4
done

# randomly fill the filesystem so the performance enters the steady state
for once in 0
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/fs_steady_rf.fio --output=$RESDIR/steady.txt
	$FIO $JOBDIR/fs_steady_rf.fio --output=$RESDIR/steady.txt
	sleep 4
done
# then benchmark the IOPS and latency performance
for i in {0..7}
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/fs_std_iops_4k.fio --output=$RESDIR/iops_4k_$i.txt
	$FIO $JOBDIR/fs_std_iops_4k.fio --output=$RESDIR/iops_4k_$i.txt
	sleep 4
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/fs_std_iops_8k.fio --output=$RESDIR/iops_8k_$i.txt
	$FIO $JOBDIR/fs_std_iops_8k.fio --output=$RESDIR/iops_8k_$i.txt
	sleep 4
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/fs_std_lat.fio     --output=$RESDIR/lat_$i.txt
	$FIO $JOBDIR/fs_std_lat.fio     --output=$RESDIR/lat_$i.txt
	sleep 4
done
