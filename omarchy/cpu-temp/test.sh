#!/usr/bin/env bash
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

node "$tool_dir/test_model.js"

# sensors.sh against a fake /sys/class: coretemp wins over a thermal zone.
fake=$(mktemp -d)
trap 'rm -rf -- "$fake"' EXIT
mkdir -p "$fake/hwmon/hwmon0" "$fake/hwmon/hwmon1" "$fake/thermal/thermal_zone0"
echo acpitz > "$fake/hwmon/hwmon0/name"; echo 40000 > "$fake/hwmon/hwmon0/temp1_input"
echo coretemp > "$fake/hwmon/hwmon1/name"
echo 'Package id 0' > "$fake/hwmon/hwmon1/temp1_label"; echo 72500 > "$fake/hwmon/hwmon1/temp1_input"
echo 100000 > "$fake/hwmon/hwmon1/temp1_crit"
echo 'Core 0' > "$fake/hwmon/hwmon1/temp2_label"; echo 70000 > "$fake/hwmon/hwmon1/temp2_input"
echo x86_pkg_temp > "$fake/thermal/thermal_zone0/type"; echo 55000 > "$fake/thermal/thermal_zone0/temp"

TOOLBOX_CPUTEMP_SYSFS=$fake "$tool_dir/sensors.sh" | jq -e '
  .source == "coretemp" and (.sensors | length) == 2
  and .sensors[0].label == "Package id 0" and .sensors[0].celsius == 72.5
  and .sensors[0].crit == 100 and .sensors[1].max == null' > /dev/null \
  || { echo 'FAIL: sensors.sh should read coretemp' >&2; exit 1; }

# Without a CPU hwmon driver, the CPU thermal zone is used.
rm -rf "$fake/hwmon/hwmon1"
TOOLBOX_CPUTEMP_SYSFS=$fake "$tool_dir/sensors.sh" | jq -e '
  .source == "thermal:x86_pkg_temp" and .sensors[0].celsius == 55' > /dev/null \
  || { echo 'FAIL: sensors.sh should fall back to the thermal zone' >&2; exit 1; }

# Nothing at all: still valid JSON, no sensors.
TOOLBOX_CPUTEMP_SYSFS=/nonexistent "$tool_dir/sensors.sh" | jq -e '.sensors == []' > /dev/null \
  || { echo 'FAIL: sensors.sh should report no sensors' >&2; exit 1; }

"$tool_dir/install.sh" --check > /dev/null || { echo 'FAIL: plugin is invalid' >&2; exit 1; }
echo 'PASS: temperature model, sensor discovery, plugin manifest.'
