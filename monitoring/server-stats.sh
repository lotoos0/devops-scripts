#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Show CPU usage
cpu_usage() {
  read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 g1 gn1 </proc/stat
  idle1=$((i1 + w1))
  nonidle1=$((u1 + n1 + s1 + q1 + sq1 + st1))
  total1=$((idle1 + nonidle1))

  sleep 1

  read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 g2 gn2 </proc/stat
  idle2=$((i2 + w2))
  nonidle2=$((u2 + n2 + s2 + q2 + sq2 + st2))
  total2=$((idle2 + nonidle2))

  dt=$((total2 - total1))
  di=$((idle2 - idle1))
  if ((dt == 0)); then
    echo "0.0"
    return
  fi
  awk -v dt="$dt" -v di="$di" 'BEGIN { printf "%.1f", (1 - di/dt) * 100 }'
}

printf "${BOLD}${CYAN}CPU Usage:${RESET} %s%%\n" "$(cpu_usage)"

# Show Memory usage
mem_usage() {
  local total available free buffers cached sreclaimable
  total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

  if [[ -z "$available" || "$available" -eq 0 ]]; then
    free=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    buffers=$(awk '/^Buffers:/ {print $2}' /proc/meminfo)
    cached=$(awk '/^Cached:/ {print $2}' /proc/meminfo)
    sreclaimable=$(awk '/^SReclaimable:/ {print $2}' /proc/meminfo)
    available=$((free + buffers + cached + sreclaimable))
  fi

  local used=$((total - available))

  awk -v t="$total" -v a="$available" -v u="$used" -v g="$GREEN" -v r="$RESET" -v b="$BOLD" '
    BEGIN {
      pct = (u / t) * 100
      printf "%s%sMemory:%s used %.2f GiB / %.2f GiB (%.1f%%) | free %.2f GiB (%.1f%%)\n",
             b, g, r, u/1048576, t/1048576, pct, a/1048576, (a/t)*100
    }'
}

mem_usage

# Show Disk usage
disk_usage() {
  local line
  line=$(df -h --total | awk '/total/ {print $2, $3, $4, $5}')

  awk -v y="$YELLOW" -v r="$RESET" -v b="$BOLD" '{printf "%s%sDisk:%s used %s / %s (free %s, %s)\n", b, y, r, $2, $1, $3, $4}' <<<"$line"
}

disk_usage

# Top 5 processes by CPU usage
top_cpu_processes() {
  echo -e "${BOLD}${BLUE}Top 5 processes by CPU usage:${RESET}"
  ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
  echo
}

top_cpu_processes

# Top 5 processes by Memory usage
top_mem_processes() {
  echo -e "${BOLD}${BLUE}Top 5 processes by Memory usage:${RESET}"
  ps -eo pid,comm,%mem --sort=-%mem | head -n 6
  echo
}

top_mem_processes
