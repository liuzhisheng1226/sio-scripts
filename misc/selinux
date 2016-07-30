#!/usr/bin/env bash
# Set up SELinux.

set -e

if [ -z $1 ]; then
	echo "Argument(s) Required!" >&2
	echo "Usage: $(basename $0) [enforcing|permissive|disabled]"
	exit 1
fi

if [[ $1 != "enforcing" && $1 != "permissive" && $1 != "disabled" ]]; then
	echo "Invalid Argument(s): $1" >&2
	echo "Usage: $(basename $0) [enforcing|permissive|disabled]"
	exit 1
fi

[ -f /etc/selinux/config ] || { echo "ERROR: /etc/selinux/config not found!"; exit 1; }

if   [ $1 == "enforcing"  ]; then
	sed -i -- 's/^SELINUX=.\+/SELINUX=enforcing/g'  /etc/selinux/config
elif [ $1 == "permissive" ]; then
	sed -i -- 's/^SELINUX=.\+/SELINUX=permissive/g' /etc/selinux/config
elif [ $1 == "disabled"   ]; then
	sed -i -- 's/^SELINUX=.\+/SELINUX=disabled/g'   /etc/selinux/config
fi

echo "Done! Please reboot your system!"
