#!/usr/bin/env bash
# demonstration of doing a full NVMe SSD benchmarking using SPDK.
# this may take a couple of days and nights.

# set up perf and fio executables and the working directory
PERF=perf
[[ -z $1 ]] || PERF=$1
FIO=fio
[[ -z $2 ]] || FIO=$2
JOBDIR=.
[[ -z $3 ]] || JOBDIR=$3
RESDIR=$JOBDIR/res/user
[[ -d $RESDIR ]] || mkdir -p $RESDIR

# sequentially fill the drive several times
for each in {0..3}
do
	dd if=/dev/zero of=/dev/nvme0n1 bs=1M oflag=direct
	sleep 4
done
# then benchmark the bandwidth performance: 1 thread, transfer unit 128KB, queue depth 128
for each in {0..7}
do
	$PERF -c 0x100 -s 131072 -q 128 -w write -t 180 2>&1 | tee -a $RESDIR/bw_r128k.txt
	sleep 4
	$PERF -c 0x100 -s 131072 -q 128 -w read  -t 180 2>&1 | tee -a $RESDIR/bw_w128k.txt
	sleep 4
done

# randomly write the drive so the performance enters the steady state
for once in 1
do
#	numactl --cpunodebind=1 --membind=1 $FIO $JOBDIR/raw_std_steady.fio
	$FIO $JOBDIR/raw_std_steady.fio
	sleep 4
done
# then benchmark the IOPS and latency performance: 4KB/8KB random RW, 1T/QD128 or 4T/QD32
for each in {0..7}
do
#	$PERF -c 0xf00 -s 4096 -q 32  -w randwrite -t 180 2>&1 | tee -a $RESDIR/iops_rw4k.txt
#	sleep 4
#	$PERF -c 0xf00 -s 4096 -q 32  -w randread  -t 180 2>&1 | tee -a $RESDIR/iops_rr4k.txt
#	sleep 4
	$PERF -c 0x100 -s 4096 -q 128 -w randwrite -t 180 2>&1 | tee -a $RESDIR/iops_rw4k1t.txt
	sleep 4
	$PERF -c 0x100 -s 4096 -q 128 -w randread  -t 180 2>&1 | tee -a $RESDIR/iops_rr4k1t.txt
	sleep 4
#	$PERF -c 0xf00 -s 8192 -q 32  -w randread  -t 180 2>&1 | tee -a $RESDIR/iops_rr8k.txt
#	sleep 4
#	$PERF -c 0xf00 -s 8192 -q 32  -w randwrite -t 180 2>&1 | tee -a $RESDIR/iops_rw8k.txt
#	sleep 4
	$PERF -c 0x100 -s 8192 -q 128 -w randwrite -t 180 2>&1 | tee -a $RESDIR/iops_rw8k1t.txt
	sleep 4
	$PERF -c 0x100 -s 8192 -q 128 -w randread  -t 180 2>&1 | tee -a $RESDIR/iops_rr8k1t.txt
	sleep 4
	$PERF -c 0x100 -s 4096 -q 1   -w randwrite -t 180 2>&1 | tee -a $RESDIR/lat_rw4k.txt
	sleep 4
	$PERF -c 0x100 -s 4096 -q 1   -w randread  -t 180 2>&1 | tee -a $RESDIR/lat_rr4k.txt
	sleep 4
done
