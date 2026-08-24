#!/bin/bash
set -u
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
collect_hwmon() {
  shopt -s nullglob 2>/dev/null || true
  for hw in /sys/class/hwmon/hwmon*; do
    [ -d "$hw" ] || continue
    name=$(cat "$hw/name" 2>/dev/null || cat "$hw/device/name" 2>/dev/null || echo "")
    for f in "$hw"/temp*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then
        label="${name} ${label}"
      else
        if [ "$name" != "$label" ] && [ -n "$name" ]; then label="${name} ${label}"; fi
      fi
      case "$label" in
        "acpitz temp1") label="ACPI Thermal Zone" ;;
        "pch_cannonlake temp1") label="Platform Controller Hub" ;;
        "iwlwifi_1 temp1") label="Wireless Adapter" ;;
      esac
      label=$(echo "$label" | sed 's/Package id 0/Processor 0/; s/Package id 1/Processor 1/; s/Package id/CPU/')
      printf '{"label":"%s","value":%s,"type":"temperature","format":"temp"}\n' "$(json_escape "$label")" "$val"
    done
    for f in "$hw"/device/temp*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then label="${name} ${label}"; else if [ -n "$name" ] && [ "$name" != "$label" ]; then label="${name} ${label}"; fi; fi
      case "$label" in "acpitz temp1") label="ACPI Thermal Zone";; "pch_cannonlake temp1") label="Platform Controller Hub";; "iwlwifi_1 temp1") label="Wireless Adapter";; esac
      label=$(echo "$label" | sed 's/Package id 0/Processor 0/; s/Package id 1/Processor 1/; s/Package id/CPU/')
      printf '{"label":"%s","value":%s,"type":"temperature","format":"temp"}\n' "$(json_escape "$label")" "$val"
    done
    for f in "$hw"/fan*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then label="${name} ${label}"; else if [ -n "$name" ] && [ "$name" != "$label" ]; then label="${name} ${label}"; fi; fi
      printf '{"label":"%s","value":%s,"type":"fan","format":"fan"}\n' "$(json_escape "$label")" "$val"
    done
    for f in "$hw"/device/fan*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then label="${name} ${label}"; else if [ -n "$name" ] && [ "$name" != "$label" ]; then label="${name} ${label}"; fi; fi
      printf '{"label":"%s","value":%s,"type":"fan","format":"fan"}\n' "$(json_escape "$label")" "$val"
    done
    for f in "$hw"/in*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then label="${name} ${label}"; else if [ -n "$name" ] && [ "$name" != "$label" ]; then label="${name} ${label}"; fi; fi
      printf '{"label":"%s","value":%s,"type":"voltage","format":"in"}\n' "$(json_escape "$label")" "$val"
    done
    for f in "$hw"/device/in*_input; do
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      base=$(basename "$f" _input)
      label_file="${f%_input}_label"
      label=$(cat "$label_file" 2>/dev/null || echo "$base")
      if [ "$label" = "$base" ]; then label="${name} ${label}"; else if [ -n "$name" ] && [ "$name" != "$label" ]; then label="${name} ${label}"; fi; fi
      printf '{"label":"%s","value":%s,"type":"voltage","format":"in"}\n' "$(json_escape "$label")" "$val"
    done
  done
  shopt -u nullglob 2>/dev/null || true
}
collect_memory() {
  if [ -f /proc/meminfo ]; then
    total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
    swapTotal=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)
    swapFree=$(awk '/SwapFree:/ {print $2}' /proc/meminfo)
    cached=$(awk '/^Cached:/ {print $2}' /proc/meminfo | head -1)
    memFree=$(awk '/MemFree:/ {print $2}' /proc/meminfo)
    total=${total:-0}; avail=${avail:-0}; swapTotal=${swapTotal:-0}; swapFree=${swapFree:-0}; cached=${cached:-0}; memFree=${memFree:-0}
    if [ "$total" -gt 0 ]; then
      used=$((total - avail))
      avail_pct=$(awk "BEGIN {print $avail/$total}")
      used_pct=$(awk "BEGIN {print $used/$total}")
      swapUsed=$((swapTotal - swapFree))
      swap_pct=$(awk "BEGIN {if($swapTotal>0) print $swapUsed/$swapTotal; else print 0}")
      printf '{"label":"Usage","value":%s,"type":"memory","format":"percent"}\n' "$used_pct"
      printf '{"label":"memory","value":%s,"type":"memory-group","format":"percent"}\n' "$used_pct"
      printf '{"label":"Physical","value":%s,"type":"memory","format":"memory"}\n' "$total"
      printf '{"label":"Available","value":%s,"type":"memory","format":"memory"}\n' "$avail"
      printf '{"label":"Allocated","value":%s,"type":"memory","format":"memory"}\n' "$used"
      printf '{"label":"Cached","value":%s,"type":"memory","format":"memory"}\n' "$cached"
      printf '{"label":"Free","value":%s,"type":"memory","format":"memory"}\n' "$memFree"
      printf '{"label":"Swap Total","value":%s,"type":"memory","format":"memory"}\n' "$swapTotal"
      printf '{"label":"Swap Free","value":%s,"type":"memory","format":"memory"}\n' "$swapFree"
      printf '{"label":"Swap Used","value":%s,"type":"memory","format":"memory"}\n' "$swapUsed"
      printf '{"label":"Swap Usage","value":%s,"type":"memory","format":"percent"}\n' "$swap_pct"
    fi
  fi
}
collect_processor() {
  if [ -f /proc/stat ]; then
    grep -E '^cpu[0-9]* ' /proc/stat | while read -r cpu user nice system rest; do
      total=$((user + nice + system))
      printf '{"label":"%s","value":%d,"type":"processor-stat","format":"raw"}\n' "$cpu" "$total"
    done
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do [ -f "$f" ] && cat "$f"; done | awk '
        { sum+=$1; n++; if($1>max) max=$1; if(min==""||$1<min) min=$1 }
        END { if(n>0) printf "{\"label\":\"Frequency\",\"value\":%d,\"type\":\"processor\",\"format\":\"hertz\"}\n", (sum/n)*1000;
              if(n>0) printf "{\"label\":\"Max frequency\",\"value\":%d,\"type\":\"processor\",\"format\":\"hertz\"}\n", max*1000;
              if(n>0) printf "{\"label\":\"Min frequency\",\"value\":%d,\"type\":\"processor\",\"format\":\"hertz\"}\n", min*1000;
        }'
    else
      awk '/^cpu MHz/ { sum+=$4; n++; if($4>max) max=$4; if(min==""||$4<min) min=$4 }
        END { if(n>0) printf "{\"label\":\"Frequency\",\"value\":%.0f,\"type\":\"processor\",\"format\":\"hertz\"}\n", (sum/n)*1000000;
              if(n>0) printf "{\"label\":\"Max frequency\",\"value\":%.0f,\"type\":\"processor\",\"format\":\"hertz\"}\n", max*1000000;
              if(n>0) printf "{\"label\":\"Min frequency\",\"value\":%.0f,\"type\":\"processor\",\"format\":\"hertz\"}\n", min*1000000;
        }' /proc/cpuinfo
    fi
  fi
  if [ "${1:-}" = "--static" ]; then
    vendor=$(awk -F': ' '/vendor_id/ {print $2; exit}' /proc/cpuinfo)
    bogomips=$(awk -F': ' '/bogomips/ {print $2; exit}' /proc/cpuinfo)
    sockets=$(awk -F': ' '/physical id/ {s[$2]=1} END{print length(s)}' /proc/cpuinfo)
    cache=$(awk -F': ' '/cache size/ {print $2; exit}' /proc/cpuinfo)
    [ -n "$vendor" ] && printf '{"label":"Vendor","value":"%s","type":"processor","format":"string"}\n' "$(json_escape "$vendor")"
    [ -n "$bogomips" ] && printf '{"label":"Bogomips","value":"%s","type":"processor","format":"string"}\n' "$(json_escape "$bogomips")"
    [ -n "$sockets" ] && printf '{"label":"Sockets","value":"%s","type":"processor","format":"string"}\n' "$sockets"
    [ -n "$cache" ] && printf '{"label":"Cache","value":"%s","type":"processor","format":"memory"}\n' "$(json_escape "$cache")"
  fi
}
collect_system() {
  if [ -f /proc/loadavg ]; then
    read l1 l5 l15 rest < /proc/loadavg
    threads=$(echo "$rest" | cut -d' ' -f1 | cut -d'/' -f1)
    threads_tot=$(echo "$rest" | cut -d' ' -f1 | cut -d'/' -f2)
    printf '{"label":"Load 1m","value":%s,"type":"system","format":"load"}\n' "$l1"
    printf '{"label":"system","value":%s,"type":"system-group","format":"load"}\n' "$l1"
    printf '{"label":"Load 5m","value":%s,"type":"system","format":"load"}\n' "$l5"
    printf '{"label":"Load 15m","value":%s,"type":"system","format":"load"}\n' "$l15"
    printf '{"label":"Threads Active","value":"%s","type":"system","format":"string"}\n' "$threads"
    printf '{"label":"Threads Total","value":"%s","type":"system","format":"string"}\n' "$threads_tot"
  fi
  if [ -f /proc/sys/fs/file-nr ]; then
    read open _ _ < /proc/sys/fs/file-nr
    printf '{"label":"Open Files","value":"%s","type":"system","format":"string"}\n' "$open"
  fi
  if [ -f /proc/uptime ]; then
    read up idle < /proc/uptime
    printf '{"label":"Uptime","value":%s,"type":"system","format":"uptime"}\n' "$up"
    cores=$(nproc 2>/dev/null || echo 1)
    proc_time=$(awk "BEGIN {print $up - $idle/$cores}")
    printf '{"label":"Process Time","value":%s,"type":"processor","format":"uptime"}\n' "$proc_time"
  fi
  if [ "${1:-}" = "--static" ] && [ -f /proc/version ]; then
    kern=$(awk '{print $3}' /proc/version)
    printf '{"label":"Kernel","value":"%s","type":"system","format":"string"}\n' "$(json_escape "$kern")"
  fi
}
collect_network() {
  for iface in /sys/class/net/*; do
    [ -d "$iface" ] || continue
    name=$(basename "$iface")
    for dir in rx tx; do
      [ "$name" = "lo" ] && [ "$dir" = "rx" ] && continue
      f="$iface/statistics/${dir}_bytes"
      [ -f "$f" ] || continue
      val=$(cat "$f" 2>/dev/null); [ -n "$val" ] || continue
      if [ "$name" = "lo" ]; then
        label="$name"
        type="network"
      else
        label="$name $dir"
        type="network-$dir"
      fi
      printf '{"label":"%s","value":%s,"type":"%s","format":"storage"}\n' "$(json_escape "$label")" "$val" "$type"
    done
  done
  if [ -f /proc/net/wireless ]; then
    awk 'NR>3 { qual=$3; sig=$4; gsub(/\./,"",qual); gsub(/\./,"",sig); printf "{\"label\":\"WiFi Link Quality\",\"value\":%.4f,\"type\":\"network\",\"format\":\"percent\"}\n", qual/70; printf "{\"label\":\"WiFi Signal Level\",\"value\":\"%s\",\"type\":\"network\",\"format\":\"string\"}\n", sig }' /proc/net/wireless 2>/dev/null
  fi
}
collect_storage() {
  path="${1:-/}"
  if command -v df >/dev/null 2>&1; then
    out=$(df -B1 "$path" 2>/dev/null | tail -1)
    if [ -n "$out" ]; then
      total=$(echo "$out" | awk '{print $2}')
      used=$(echo "$out" | awk '{print $3}')
      avail=$(echo "$out" | awk '{print $4}')
      printf '{"label":"Total","value":%s,"type":"storage","format":"storage"}\n' "$total"
      printf '{"label":"Used","value":%s,"type":"storage","format":"storage"}\n' "$used"
      printf '{"label":"Free","value":%s,"type":"storage","format":"storage"}\n' "$avail"
      printf '{"label":"storage","value":%s,"type":"storage-group","format":"storage"}\n' "$avail"
      if [ "$total" -gt 0 ]; then
        used_pct=$(( used * 100 / total ))
        free_pct=$(( 100 - used_pct ))
        printf '{"label":"Used %%","value":"%s%%","type":"storage","format":"string"}\n' "$used_pct"
        printf '{"label":"Free %%","value":"%s%%","type":"storage","format":"string"}\n' "$free_pct"
      fi
    fi
  fi
  if [ -f /proc/diskstats ]; then
    awk '{ read=$6*512; write=$10*512; printf "{\"label\":\"Read total\",\"value\":%d,\"type\":\"storage\",\"format\":\"storage\"}\n", read; printf "{\"label\":\"Write total\",\"value\":%d,\"type\":\"storage\",\"format\":\"storage\"}\n", write; exit }' /proc/diskstats 2>/dev/null
  fi
  if [ -f /proc/spl/kstat/zfs/arcstats ]; then
    awk '/^c /{t=$4} /^c_max /{m=$4} /^size /{c=$4} END{ if(t) printf "{\"label\":\"ARC Target\",\"value\":%s,\"type\":\"storage\",\"format\":\"storage\"}\n", t; if(m) printf "{\"label\":\"ARC Maximum\",\"value\":%s,\"type\":\"storage\",\"format\":\"storage\"}\n", m; if(c) printf "{\"label\":\"ARC Current\",\"value\":%s,\"type\":\"storage\",\"format\":\"storage\"}\n", c }' /proc/spl/kstat/zfs/arcstats 2>/dev/null
  fi
}
collect_battery() {
  slot=${1:-0}
  case $slot in
    0) p="BAT0";; 1) p="BAT1";; 2) p="BAT2";; 3) p="BATT";; 4) p="CMB0";; 5) p="CMB1";; 6) p="CMB2";; 7) p="macsmc-battery";; *) p="BAT0";;
  esac
  f="/sys/class/power_supply/$p/uevent"
  [ -f "$f" ] || return
  STATUS=""; CYCLE_COUNT=""; VOLTAGE_NOW=""; CAPACITY_LEVEL=""; CAPACITY=""; POWER_NOW=""; CURRENT_NOW=""; ENERGY_FULL=""; ENERGY_FULL_DESIGN=""
  while IFS='=' read -r k v; do
    case "$k" in
      POWER_SUPPLY_STATUS) STATUS=$(printf '%s' "$v" | head -c 64 | tr -cd 'A-Za-z0-9_ ') ;;
      POWER_SUPPLY_CYCLE_COUNT) CYCLE_COUNT=$(printf '%s' "$v" | tr -cd '0-9' | head -c 16) ;;
      POWER_SUPPLY_VOLTAGE_NOW) VOLTAGE_NOW=$(printf '%s' "$v" | tr -cd '0-9' | head -c 16) ;;
      POWER_SUPPLY_CAPACITY_LEVEL) CAPACITY_LEVEL=$(printf '%s' "$v" | head -c 32 | tr -cd 'A-Za-z0-9_ ') ;;
      POWER_SUPPLY_CAPACITY) CAPACITY=$(printf '%s' "$v" | tr -cd '0-9' | head -c 8) ;;
      POWER_SUPPLY_POWER_NOW) POWER_NOW=$(printf '%s' "$v" | tr -cd '0-9-' | head -c 16) ;;
      POWER_SUPPLY_CURRENT_NOW) CURRENT_NOW=$(printf '%s' "$v" | tr -cd '0-9-' | head -c 16) ;;
      POWER_SUPPLY_ENERGY_FULL) ENERGY_FULL=$(printf '%s' "$v" | tr -cd '0-9' | head -c 16) ;;
      POWER_SUPPLY_ENERGY_FULL_DESIGN) ENERGY_FULL_DESIGN=$(printf '%s' "$v" | tr -cd '0-9' | head -c 16) ;;
    esac
  done < <(head -c 4096 "$f" | head -n 50)
  [ -n "$STATUS" ] && printf '{"label":"State","value":"%s","type":"battery","format":"string"}\n' "$(json_escape "$STATUS")"
  [ -n "$CYCLE_COUNT" ] && printf '{"label":"Cycles","value":"%s","type":"battery","format":"string"}\n' "$CYCLE_COUNT"
  [ -n "$VOLTAGE_NOW" ] && printf '{"label":"Voltage","value":%s,"type":"battery","format":"in"}\n' "$((VOLTAGE_NOW/1000))"
  [ -n "$CAPACITY_LEVEL" ] && printf '{"label":"Level","value":"%s","type":"battery","format":"string"}\n' "$(json_escape "$CAPACITY_LEVEL")"
  [ -n "$CAPACITY" ] && awk "BEGIN {print $CAPACITY/100}" | xargs -I{} printf '{"label":"Percentage","value":%s,"type":"battery","format":"percent"}\n' "{}"
  if [ -n "$POWER_NOW" ]; then
    pwr=$POWER_NOW
    [ "$STATUS" = "Discharging" ] && pwr=$(( -pwr ))
    printf '{"label":"Power Rate","value":%s,"type":"battery","format":"watt"}\n' "$pwr"
    printf '{"label":"battery","value":%s,"type":"battery-group","format":"watt"}\n' "$pwr"
  elif [ -n "$VOLTAGE_NOW" ] && [ -n "$CURRENT_NOW" ]; then
    pwr=$(( VOLTAGE_NOW * CURRENT_NOW / 1000000 ))
    [ "$STATUS" = "Discharging" ] && pwr=$(( -pwr ))
    printf '{"label":"Power Rate","value":%s,"type":"battery","format":"watt"}\n' "$pwr"
    printf '{"label":"battery","value":%s,"type":"battery-group","format":"watt"}\n' "$pwr"
  fi
  [ -n "$ENERGY_FULL" ] && printf '{"label":"Energy (full)","value":%s,"type":"battery","format":"watt-hour"}\n' "$ENERGY_FULL"
  [ -n "$ENERGY_FULL_DESIGN" ] && printf '{"label":"Energy (design)","value":%s,"type":"battery","format":"watt-hour"}\n' "$ENERGY_FULL_DESIGN"
}
collect_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,fan.speed,temperature.gpu,temperature.memory,memory.total,memory.used,memory.reserved,memory.free,utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder,clocks.gr,clocks.mem,clocks.video,power.draw.instant,power.draw.average,pcie.link.gen.gpucurrent,pcie.link.width.current --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '
    {
      label=$1; fan=$2; tg=$3; tm=$4; mt=$5; mu=$6; mr=$7; mf=$8; ug=$9; um=$10; ue=$11; ud=$12; cg=$13; cm=$14; cv=$15; pd=$16; pa=$17; lg=$18; lw=$19;
      g="gpu#1";
      printf "{\"label\":\"Graphics\",\"value\":%.4f,\"type\":\"%s-group\",\"format\":\"percent\"}\n", ug/100, g;
      printf "{\"label\":\"Name\",\"value\":\"%s\",\"type\":\"%s\",\"format\":\"string\"}\n", label, g;
      printf "{\"label\":\"Fan\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", fan/100, g;
      printf "{\"label\":\"Temperature\",\"value\":%d,\"type\":\"%s\",\"format\":\"temp\"}\n", tg*1000, g;
      if(tm!="N/A" && tm!="") printf "{\"label\":\"Memory Temperature\",\"value\":%d,\"type\":\"%s\",\"format\":\"temp\"}\n", tm*1000, g;
      printf "{\"label\":\"Memory Usage\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", mu/mt, g;
      printf "{\"label\":\"Memory Total\",\"value\":%d,\"type\":\"%s\",\"format\":\"memory\"}\n", mt*1000, g;
      printf "{\"label\":\"Memory Used\",\"value\":%d,\"type\":\"%s\",\"format\":\"memory\"}\n", mu*1000, g;
      printf "{\"label\":\"Memory Reserved\",\"value\":%d,\"type\":\"%s\",\"format\":\"memory\"}\n", mr*1000, g;
      printf "{\"label\":\"Memory Free\",\"value\":%d,\"type\":\"%s\",\"format\":\"memory\"}\n", mf*1000, g;
      printf "{\"label\":\"Utilization\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", ug/100, g;
      printf "{\"label\":\"Memory Utilization\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", um/100, g;
      printf "{\"label\":\"Encoder Utilization\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", ue/100, g;
      printf "{\"label\":\"Decoder Utilization\",\"value\":%.4f,\"type\":\"%s\",\"format\":\"percent\"}\n", ud/100, g;
      printf "{\"label\":\"Frequency\",\"value\":%d,\"type\":\"%s\",\"format\":\"hertz\"}\n", cg*1000000, g;
      printf "{\"label\":\"Memory Frequency\",\"value\":%d,\"type\":\"%s\",\"format\":\"hertz\"}\n", cm*1000000, g;
      printf "{\"label\":\"Encoder/Decoder Frequency\",\"value\":%d,\"type\":\"%s\",\"format\":\"hertz\"}\n", cv*1000000, g;
      printf "{\"label\":\"Power\",\"value\":\"%s\",\"type\":\"%s\",\"format\":\"watt-gpu\"}\n", pd, g;
      printf "{\"label\":\"Average Power\",\"value\":\"%s\",\"type\":\"%s\",\"format\":\"watt-gpu\"}\n", pa, g;
      printf "{\"label\":\"Link Speed\",\"value\":\"%sx%s\",\"type\":\"%s\",\"format\":\"pcie\"}\n", lg, lw, g;
      printf "{\"label\":\"GPU 1\",\"value\":%d,\"type\":\"temperature\",\"format\":\"temp\"}\n", tg*1000;
    }'
    return
  fi
  for i in 0 1 2 3 4 5; do
    [ -f "/sys/class/drm/card$i/device/vendor" ] || continue
    vendor=$(cat "/sys/class/drm/card$i/device/vendor" 2>/dev/null)
    g="gpu#1"
    [ "$i" != "0" ] && g="gpu#$((i+1))"
    if [ "$vendor" = "0x1002" ]; then
      if [ -f "/sys/class/drm/card$i/device/gpu_busy_percent" ]; then
        val=$(cat "/sys/class/drm/card$i/device/gpu_busy_percent" 2>/dev/null)
        [ -n "$val" ] && printf '{"label":"Graphics","value":%.4f,"type":"%s-group","format":"percent"}\n' "$(awk "BEGIN{print $val/100}")" "$g"
        [ -n "$val" ] && printf '{"label":"Usage","value":%.4f,"type":"%s","format":"percent"}\n' "$(awk "BEGIN{print $val/100}")" "$g"
        printf '{"label":"Vendor","value":"AMD","type":"%s","format":"string"}\n' "$g"
      fi
      for key in "mem_info_vram_used:Memory Used" "mem_info_vram_total:Memory Total"; do
        k=${key%%:*}; l=${key
        f="/sys/class/drm/card$i/device/$k"
        [ -f "$f" ] || continue
        v=$(cat "$f" 2>/dev/null) && printf '{"label":"%s","value":%s,"type":"%s","format":"memory"}\n' "$l" "$v" "$g"
      done
    else
      case "$vendor" in
        0x10DE) vn="NVIDIA";; 0x8086) vn="Intel";; 0x13B5) vn="ARM";; 0x5143) vn="Qualcomm";; *) vn="Unknown $vendor";;
      esac
      printf '{"label":"Graphics","value":"%s","type":"%s-group","format":"string"}\n' "$(json_escape "$vn")" "$g"
    fi
  done
}
MODE="all"
STORAGE_PATH="/"
BATTERY_SLOT=0
STATIC=false
while [ $# -gt 0 ]; do
  case "$1" in
    --storage-path) STORAGE_PATH="$2"; shift 2;;
    --battery-slot) BATTERY_SLOT="$2"; shift 2;;
    --static) STATIC=true; shift;;
    --mode) MODE="$2"; shift 2;;
    *) shift;;
  esac
done
if [ "$STATIC" = true ]; then
  collect_processor --static
  collect_system --static
else
  collect_hwmon
  collect_memory
  collect_processor
  collect_system
  collect_network
  collect_storage "$STORAGE_PATH"
  collect_battery "$BATTERY_SLOT"
  collect_gpu
fi