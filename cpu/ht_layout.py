#! /usr/bin/python

import sys

sockets = []
cores = []
core_map = {}

fd=open("/proc/cpuinfo")
lines = fd.readlines()
fd.close()

core_details = []
core_lines = {}
for line in lines:
	if len(line.strip()) != 0:
		name, value = line.split(":", 1)
		core_lines[name.strip()] = value.strip()
	else:
		core_details.append(core_lines)
		core_lines = {}

for core in core_details:
	for field in ["processor", "core id", "physical id"]:
		if field not in core:
			print "Error getting '%s' value from /proc/cpuinfo" % field
			sys.exit(1)
		core[field] = int(core[field])

	if core["core id"] not in cores:
		cores.append(core["core id"])
	if core["physical id"] not in sockets:
		sockets.append(core["physical id"])
	key = (core["physical id"], core["core id"])
	if key not in core_map:
		core_map[key] = []
	core_map[key].append(core["processor"])

print "============================================================"
print "Core and Socket Information (as reported by '/proc/cpuinfo')"
print "============================================================\n"
print "cores = ",cores
print "sockets = ", sockets
print ""

max_processor_len = len(str(len(cores) * len(sockets) * 2 - 1))
max_core_map_len = max_processor_len * 2 + len('[, ]') + len('Socket ')
max_core_id_len = len(str(max(cores)))

print " ".ljust(max_core_id_len + len('Core ')),
for s in sockets:
        print "Socket %s" % str(s).ljust(max_core_map_len - len('Socket ')),
print ""
print " ".ljust(max_core_id_len + len('Core ')),
for s in sockets:
        print "--------".ljust(max_core_map_len),
print ""

for c in cores:
        print "Core %s" % str(c).ljust(max_core_id_len),
        for s in sockets:
                print str(core_map[(s,c)]).ljust(max_core_map_len),
        print ""
