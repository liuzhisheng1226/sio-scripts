#!/usr/bin/env bash
# Enable or disable turbo boost through pstate interface.
# * lock: disable turbo and set the minimal performance to 99%.
# * unlock: enable turbo and set the minimal performance to a lower level.

set -e

if [[ -z $1 ]]; then
	echo "Argument(s) required!" >&2
	echo "Usage: $(basename $0) [lock|unlock]"
	exit 1
fi

if [[ ! -z $1 && $1 != "lock" && $1 != "unlock" ]]; then
	echo "Invalid argument(s): $1" >&2
	echo "Usage: $(basename $0) [lock|unlock]"
	exit 1
fi

if [[ $1 == "lock" ]]; then
#	echo "1"  | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
#	echo "99" | sudo tee /sys/devices/system/cpu/intel_pstate/min_perf_pct
	echo "1"  > "/sys/devices/system/cpu/intel_pstate/no_turbo"     2> /dev/null
	echo "99" > "/sys/devices/system/cpu/intel_pstate/min_perf_pct" 2> /dev/null
fi

if [[ $1 == "unlock" ]]; then
	echo "0"  > "/sys/devices/system/cpu/intel_pstate/no_turbo"     2> /dev/null
#	echo "25" > "/sys/devices/system/cpu/intel_pstate/min_perf_pct" 2> /dev/null
	echo "37" > "/sys/devices/system/cpu/intel_pstate/min_perf_pct" 2> /dev/null
#	echo "42" > "/sys/devices/system/cpu/intel_pstate/min_perf_pct" 2> /dev/null
fi
