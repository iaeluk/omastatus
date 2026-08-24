# OmaStatus

System status monitor for the Omarchy top bar — temperature, CPU, memory, network, storage, battery, and GPU with a fully configurable layout.

## Install

```sh
omarchy plugin add https://github.com/iaeluk/omastatus.git --enable
```

Enable or disable without removing:

```sh
omarchy plugin disable iaeluk.omastatus
omarchy plugin enable iaeluk.omastatus
```

Update to the latest version:

```sh
omarchy plugin update iaeluk.omastatus
```

## Quick Start

After install, pinned sensors appear in the bar with icon + value. The defaults show memory usage, 1-minute load, and network receive rate. Click the widget to open the full sensor dropdown.

## Bar Interaction

- **Left-click** — open/close the dropdown panel
- **Right-click** — refresh all sensors immediately
- **Gear icon** — enter ordering mode to rearrange pinned sensors
- **−/+ buttons** — decrease or increase the poll interval (1–60 seconds)
- **Fixed widths** — sensor values stay stable, no jumping

## Dropdown Panel

Sensors are grouped into collapsible accordions: Temperature, Fans, Voltage, Memory, Processor, System, Network, Storage, Battery, GPU.

Each row shows:

- Group icon
- Sensor label
- Current value (formatted by type)
- Pin toggle (☑ pinned / ☐ unpinned)

Click a group header to expand or collapse it. All groups start collapsed.

## Configuration

Move the widget between bar sections:

```sh
omarchy bar move iaeluk.omastatus --section left|center|right
```

Or edit `~/.config/omarchy/shell.json` directly:

```json
{
  "id": "iaeluk.omastatus",
  "hotSensors": ["_memory_usage_", "_system_load_1m_"],
  "updateTime": 3
}
```

### Sensor Keys

Hot sensor keys follow the pattern `_group_label_` or `__group-label__`. Examples:

| Key | Description |
|-----|-------------|
| `_memory_usage_` | Memory usage percent |
| `_system_load_1m_` | 1-minute load average |
| `__network-rx_max__` | Max network receive rate |
| `_temperature_k10temp_0_Tctl_` | CPU Tctl temperature |
| `_processor_frequency_` | CPU frequency |

Leave `hotSensors` empty to use the defaults.

### All Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `hotSensors` | stringList | `[_memory_usage_, _system_load_1m_, __network-rx_max__]` | Sensors pinned to the bar (max 20) |
| `updateTime` | integer | `2` | Poll interval in seconds (1–60) |
| `positionInPanel` | select | `right` | Bar section: `left`, `center`, `right` |
| `useHigherPrecision` | boolean | `false` | Extra decimal place |
| `alphabetize` | boolean | `true` | Sort sensors alphabetically in dropdown |
| `hideZeros` | boolean | `false` | Hide sensors with value 0 |
| `hideIcons` | boolean | `false` | Show only values in the bar |
| `fixedWidths` | boolean | `true` | Prevent sensor width from jumping |
| `unit` | select | `0` | Temperature unit: `0` Celsius, `1` Fahrenheit |
| `showTemperature` | boolean | `true` | Show temperature sensors |
| `showVoltage` | boolean | `false` | Show voltage sensors |
| `showFan` | boolean | `true` | Show fan speed sensors |
| `showMemory` | boolean | `true` | Show memory sensors |
| `showProcessor` | boolean | `true` | Show processor sensors |
| `showSystem` | boolean | `true` | Show system sensors |
| `showNetwork` | boolean | `true` | Show network sensors |
| `showStorage` | boolean | `true` | Show storage sensors |
| `showBattery` | boolean | `false` | Show battery sensors |
| `showGpu` | boolean | `false` | Show GPU sensors (requires `nvidia-smi` or `/sys/class/drm`) |
| `includePublicIp` | boolean | `true` | Include public IP in network stats |
| `networkPublicIpInterval` | integer | `60` | Public IP refresh interval in minutes (1–1440) |
| `networkSpeedFormat` | select | `0` | `0` Bytes/s, `1` Bits/s |
| `networkSpeedUnit` | select | `0` | `0` Auto, `1` Kbps/KiB/s, `2` Mbps/MiB/s |
| `storagePath` | string | `/` | Filesystem path for storage stats |
| `memoryMeasurement` | select | `1` | `0` GiB (1024), `1` GB (1000) |
| `storageMeasurement` | select | `1` | `0` GiB (1024), `1` GB (1000) |
| `batterySlot` | integer | `0` | Battery slot index (0–7) |
| `monitorCmd` | string | `gnome-system-monitor` | System monitor command |
| `includeStaticInfo` | boolean | `false` | Show static CPU info (vendor, cache) |
| `includeStaticGpuInfo` | boolean | `false` | Show static GPU info |
| `iconStyle` | select | `0` | `0` Original, `1` GNOME |

## Sensors Collected

| Group | Source | Sensors |
|-------|--------|---------|
| Temperature | `/sys/class/hwmon/hwmon*/temp*_input` | Per-core CPU, GPU edge, NVMe, platform |
| Fans | `/sys/class/hwmon/hwmon*/fan*_input` | CPU cooler, GPU fans |
| Voltage | `/sys/class/hwmon/hwmon*/in*_input` | Vcore, SoC, auxiliary |
| Memory | `/proc/meminfo` | Usage, physical, available, allocated, cached, free, swap |
| Processor | `/proc/stat`, `/sys/devices/system/cpu/*/cpufreq` | Per-core usage, frequency (avg/max/min) |
| System | `/proc/loadavg`, `/proc/uptime`, `/proc/sys/fs/file-nr` | Load 1m/5m/15m, uptime, threads, open files |
| Network | `/sys/class/net/*/statistics/*_bytes` | RX/TX bytes per interface, WiFi signal |
| Storage | `df`, `/proc/diskstats`, ZFS arcstats | Total, used, free, read/write totals |
| Battery | `/sys/class/power_supply/BAT*/uevent` | Percentage, power rate, voltage, cycles, energy |
| GPU | `nvidia-smi` or `/sys/class/drm/card*/device/` | Utilization, memory, temperature, fan, frequency, power, PCIe |

## Languages

Interface auto-detects from `Qt.locale()` with fallback to English. Supported:

- English
- Portugues
- Chinese (Simplified)
- Espanol
- Japanese

## Security

- Collector runs with a **4-second timeout** and parses all device data as key=value pairs (never sourced as shell code)
- Hot sensors capped at **20**, dropdown rows at **30**, groups at **12**
- All text rendered as **PlainText** (no rich text resource loading)
- Battery uevent values sanitized with character whitelisting and length limits

## Remove

```sh
omarchy plugin remove iaeluk.omastatus --yes
```

## License

MIT — see [LICENSE](LICENSE).
