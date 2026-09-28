#!/usr/bin/env bash
# Print the CPU temperature sensors as JSON, for the toolbox.cpu-temp widget:
#   {"source": "coretemp", "sensors": [{"label", "path", "celsius", "max", "crit"}]}
# Looks for a CPU hwmon driver first (Intel coretemp, AMD k10temp/zenpower,
# ARM cpu_thermal), then falls back to a CPU thermal zone. Always exits 0;
# `sensors` is empty when nothing was found. TOOLBOX_CPUTEMP_SYSFS replaces
# /sys/class (used by the tests).
set -uo pipefail
shopt -s nullglob

sysfs=${TOOLBOX_CPUTEMP_SYSFS:-/sys/class}
millis() { local v; { read -r v < "$1"; } 2>/dev/null && [[ $v =~ ^-?[0-9]+$ ]] && echo "$v"; }

rows=()
source_name=""
for driver in coretemp k10temp zenpower cpu_thermal; do
  for hwmon in "$sysfs"/hwmon/hwmon*; do
    [[ $(cat "$hwmon/name" 2>/dev/null) == "$driver" ]] || continue
    for input in "$hwmon"/temp*_input; do
      value=$(millis "$input") || continue
      base=${input%_input}
      label=$(cat "${base}_label" 2>/dev/null || basename "$base")
      rows+=("$label"$'\t'"$input"$'\t'"$value"$'\t'"$(millis "${base}_max")"$'\t'"$(millis "${base}_crit")")
    done
    [[ ${#rows[@]} -gt 0 ]] && { source_name=$driver; break 2; }
  done
done

if [[ ${#rows[@]} -eq 0 ]]; then
  for zone in "$sysfs"/thermal/thermal_zone*; do
    type=$(cat "$zone/type" 2>/dev/null)
    [[ $type == x86_pkg_temp || $type == cpu* || $type == soc_thermal ]] || continue
    value=$(millis "$zone/temp") || continue
    rows+=("$type"$'\t'"$zone/temp"$'\t'"$value"$'\t'$'\t')
    source_name="thermal:$type"
    break
  done
fi

printf '%s\n' "${rows[@]}" | jq -Rn --arg source "$source_name" '
  def num: if . == "" then null else tonumber / 1000 end;
  {source: $source,
   sensors: [inputs | select(. != "") | split("\t")
     | {label: .[0], path: .[1], celsius: (.[2] | num), max: (.[3] | num), crit: (.[4] | num)}]}'
