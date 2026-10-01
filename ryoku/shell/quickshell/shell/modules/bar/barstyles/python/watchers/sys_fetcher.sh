#!/usr/bin/env bash

CACHE_DIR="${QS_CACHE_SYSDATA:-/tmp/qs_sysdata}"
mkdir -p "$CACHE_DIR"
NOW=$(date +%s)

read -r _ u1 n1 s1 i1 io1 ir1 so1 st1 g1 gn1 <<< "$(grep '^cpu ' /proc/stat)"
read rx1 tx1 <<< "$(awk -v IGNORECASE=1 '/^ *[ew]/{rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev)"

sleep 0.5

read -r _ u2 n2 s2 i2 io2 ir2 so2 st2 g2 gn2 <<< "$(grep '^cpu ' /proc/stat)"
read rx2 tx2 <<< "$(awk -v IGNORECASE=1 '/^ *[ew]/{rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev)"

IDLE1=$i1; TOTAL1=$((u1 + n1 + s1 + i1 + io1 + ir1 + so1 + st1))
IDLE2=$i2; TOTAL2=$((u2 + n2 + s2 + i2 + io2 + ir2 + so2 + st2))
DIFF_IDLE=$((IDLE2 - IDLE1))
DIFF_TOTAL=$((TOTAL2 - TOTAL1))
if [ "$DIFF_TOTAL" -eq 0 ]; then CPU_USAGE=0; else CPU_USAGE=$(( 100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL )); fi

RX_RATE=$(((rx2 - rx1) * 2))
TX_RATE=$(((tx2 - tx1) * 2))

while IFS=":" read -r key val; do
    case "$key" in
        MemTotal) TOTAL_MEM=$(echo "$val" | awk '{print $1}') ;;
        MemAvailable) AVAIL_MEM=$(echo "$val" | awk '{print $1}') ;;
    esac
done < /proc/meminfo
USED_MEM=$((TOTAL_MEM - AVAIL_MEM))
RAM_PCT=$(( 100 * USED_MEM / TOTAL_MEM ))
RAM_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MEM / 1024 / 1024}")

TEMP_FILE="$CACHE_DIR/temp"
TEMP_TIME_FILE="$CACHE_DIR/temp_time"
LAST_TEMP_TIME=0
[ -f "$TEMP_TIME_FILE" ] && LAST_TEMP_TIME=$(cat "$TEMP_TIME_FILE" 2>/dev/null || echo 0)

if [ -f "$TEMP_FILE" ] && [ $((NOW - LAST_TEMP_TIME)) -lt 6 ]; then
    TEMP=$(cat "$TEMP_FILE" 2>/dev/null || echo 0)
else
    TEMP_RAW=""
    for hwmon in /sys/class/hwmon/hwmon*; do
        if [ -f "$hwmon/name" ]; then
            hwmon_name=$(cat "$hwmon/name" 2>/dev/null)
            if [[ "$hwmon_name" =~ ^(coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)$ ]]; then
                if [ -f "$hwmon/temp1_input" ]; then
                    TEMP_RAW=$(cat "$hwmon/temp1_input" 2>/dev/null)
                    break
                fi
            fi
        fi
    done

    if [ -z "$TEMP_RAW" ]; then
        for tz in /sys/class/thermal/thermal_zone*; do
            if [ -f "$tz/type" ]; then
                tz_type=$(cat "$tz/type" 2>/dev/null)
                if [[ "$tz_type" =~ ^(x86_pkg_temp|cpu_thermal|cpu-thermal)$ ]]; then
                    TEMP_RAW=$(cat "$tz/temp" 2>/dev/null)
                    break
                fi
            fi
        done
    fi

    if [ -z "$TEMP_RAW" ]; then
        TEMP_RAW=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
    fi

    if [ "$TEMP_RAW" -gt 1000 ] 2>/dev/null; then
        TEMP=$((TEMP_RAW / 1000))
    else
        TEMP=${TEMP_RAW:-0}
    fi

    echo "$TEMP" > "$TEMP_FILE"
    echo "$NOW" > "$TEMP_TIME_FILE"
fi

DISK_FILE="$CACHE_DIR/disk"
DISK_TIME_FILE="$CACHE_DIR/disk_time"
LAST_DISK_TIME=0
[ -f "$DISK_TIME_FILE" ] && LAST_DISK_TIME=$(cat "$DISK_TIME_FILE" 2>/dev/null || echo 0)

if [ -f "$DISK_FILE" ] && [ $((NOW - LAST_DISK_TIME)) -lt 60 ]; then
    read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB < "$DISK_FILE"
else
    read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB <<< "$(df -Plk -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 2>/dev/null | awk '
    NR > 1 && $1 !~ /^\/dev\/loop/ && $1 != "udev" && $1 != "none" {
        if (!seen[$1]++) {
            total += $2
            used += $3
        }
    }
    END {
        if (total > 0) {
            pct = int((used / total) * 100 + 0.5)
            printf "%d %.1f %.1f\n", pct, used / 1048576, total / 1048576
        } else {
            print "0 0.0 0.0"
        }
    }')"
    DISK_PCT=${DISK_PCT:-0}
    DISK_USED_GB=${DISK_USED_GB:-0.0}
    DISK_TOTAL_GB=${DISK_TOTAL_GB:-0.0}
    echo "$DISK_PCT $DISK_USED_GB $DISK_TOTAL_GB" > "$DISK_FILE"
    echo "$NOW" > "$DISK_TIME_FILE"
fi

echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE|$DISK_PCT|$DISK_USED_GB|$DISK_TOTAL_GB"
