#!/usr/bin/env bash
# Set CPUFreq Governor: only performance and powersave are supported.

set -e

if [[ -z $1 ]]; then
	echo "Argument(s) required!" >&2
	echo "Usage: $(basename $0) [powersave|performance]"
	exit 1
fi

if [[ ! -z $1 && $1 != "powersave" && $1 != "performance" ]]; then
	echo "Invalid argument(s): $1" >&2
	echo "Usage: $(basename $0) [powersave|performance]"
	exit 1
fi

if [[ $1 == "powersave" ]]; then
	for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
		[ -f $CPUFREQ ] || continue
		echo -n "powersave" > $CPUFREQ 2> /dev/null
	done
fi

if [[ $1 == "performance" ]]; then
	for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
		[ -f $CPUFREQ ] || continue
		echo -n "performance" > $CPUFREQ 2> /dev/null
	done
fi
