# CPU Temp — CPU temperature in the Omarchy bar

This folder is an Omarchy shell plugin, **`toolbox.cpu-temp`**: a bar widget
that always shows the CPU temperature.

- **Bar:** a thermometer that fills up towards the sensor's critical limit,
  and the CPU package temperature (` 64°`). It turns the urgent colour at
  `alertAt` (85 °C by default). On a vertical bar only the number is shown.
- **Panel (left click):** the package temperature with the sensor's critical
  limit, and every core below it.
- **Right click** opens `btop`.

It hides itself when the machine has no readable CPU sensor.

## Setup

```bash
./omarchy/cpu-temp/install.sh   # install and add to the bar, on the right
```

## Commands

```bash
./toolbox cpu-temp        # package and core temperatures, in the terminal
./toolbox cpu-temp json   # the raw sensor list the widget reads
```

## Settings

In `~/.config/omarchy/shell.json`, on the `toolbox.cpu-temp` bar entry:

| Setting | Default | Meaning |
| --- | --- | --- |
| `refreshSeconds` | `2` | How often the bar reads the temperature (minimum 1). The open panel refreshes every 2 seconds. |
| `alertAt` | `85` | °C at which the widget turns the urgent colour. `0` never does. |

## How it works

- `sensors.sh` finds the CPU sensors in `/sys/class/hwmon`, by driver name:
  `coretemp` (Intel), `k10temp` or `zenpower` (AMD), `cpu_thermal` (ARM). With
  none of those it falls back to a CPU thermal zone (`x86_pkg_temp`, `cpu*`,
  `soc_thermal`). It prints each sensor's label, file, temperature, max and
  critical limit as JSON.
- `Model.js` picks the sensor that stands for the whole CPU (`Package id 0`,
  `Tdie`, `Tctl`…, else the hottest) and formats the bar.
- `Panel.qml` runs `sensors.sh` once, then reads that one sensor file directly
  every `refreshSeconds` — no process per reading. If the file stops reading
  (hwmon numbers can change), it runs `sensors.sh` again.

To remove it from the bar: `omarchy plugin disable toolbox.cpu-temp`.

```bash
./omarchy/cpu-temp/test.sh   # model tests, sensor discovery on a fake /sys, plugin validation
```
