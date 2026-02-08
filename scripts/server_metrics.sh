#!/bin/bash

# AI atrocity

# CPU usage (user+system)
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | awk '{printf "%.0f", $1}')

# RAM usage: used and total in MB, percent
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PCT=$(( 100 * MEM_USED / MEM_TOTAL ))

# Disk usage for root (/), in MB, percent
DISK_TOTAL=$(df -m / | awk 'NR==2 {print $2}')
DISK_USED=$(df -m / | awk 'NR==2 {print $3}')
DISK_PCT=$(( 100 * DISK_USED / DISK_TOTAL ))

echo "cpu: ${CPU}%"
echo "ram: ${MEM_PCT}%"
echo "disk: ${DISK_PCT}%"