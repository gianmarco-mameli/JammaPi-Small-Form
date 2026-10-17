#!/bin/bash

set -e

operation=${1:?Missing configuration operation}
file=${2:?Missing configuration file}
mode=${3:-CRT}
model=${4:-}

case "$operation" in
    boot)
        case "$mode" in
            CRT|HDMI) ;;
            *) echo "Invalid video mode: $mode" >&2; exit 1 ;;
        esac
        ;;
    retroarch)
        mode=${3:-0}
        case "$mode" in
            0|1|2) ;;
            *) echo "Invalid CRT resolution mode: $mode" >&2; exit 1 ;;
        esac
        ;;
    audio|modules) ;;
    *) echo "Invalid configuration operation: $operation" >&2; exit 1 ;;
esac

temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT

awk -v operation="$operation" -v mode="$mode" -v model="$model" '
function trim(value) {
    sub(/^[ \t]+/, "", value)
    sub(/[ \t]+$/, "", value)
    return value
}
function setting(key, value, disabled) {
    print (disabled ? "#*" : "") key "=" value
}
function audio(disabled) {
    setting("audio_pwm_mode", "3", disabled)
    setting("disable_audio_dither", "1", disabled)
    if (model ~ /Pi 4/)
        setting("dtoverlay", "audremap,pins_18_19", disabled)
    else
        setting("dtoverlay", "pwm-2chan,pin=18,func=2,pin2=19,func2=2", disabled)
}
{
    line = $0
    normalized = trim(line)
    sub(/^[#*]+[ \t]*/, "", normalized)
    key = normalized
    sub(/[ \t]*=.*/, "", key)
    value = normalized
    sub(/^[^=]*=[ \t]*/, "", value)

    if (operation == "modules") {
        if (normalized ~ /^i2c-dev([ \t]*(#.*)?)?$/) next
    } else if (operation == "retroarch") {
        if (key == "crt_switch_resolution" || key == "crt_switch_resolution_super") next
    } else {
        if (trim(line) ~ /^\[/) section = trim(line)
        if (key == "audio_pwm_mode" || key == "disable_audio_dither") next
        if (key == "dtoverlay" && value ~ /^(audremap|pwm-2chan)([ \t,#]|$)/) next
        if (operation == "boot") {
            if (trim(line) ~ /^#([*#]*)(CRT|HDMI)[ \t]*$/) next
            if (line == "# BEGIN JammaPi" || line == "# END JammaPi") next
            if (key ~ /^(hdmi_force_hotplug|enable_dpi_lcd|display_default_lcd|dpi_output_format|dpi_group|dpi_mode|hdmi_timings)$/) next
            if (key == "dtoverlay" && value ~ /^vga666(-6)?([ \t,#]|$)/) next
            if (key == "dtparam") {
                count = split(value, parameters, ",")
                remaining = ""
                removed = 0
                for (i = 1; i <= count; i++) {
                    if (trim(parameters[i]) ~ /^i2c_vc[ \t]*=/) {
                        removed = 1
                    } else {
                        remaining = remaining (remaining == "" ? "" : ",") parameters[i]
                    }
                }
                if (removed) {
                    if (remaining != "") {
                        prefix = line
                        sub(/=.*/, "=", prefix)
                        print prefix remaining
                    }
                    next
                }
            }
        }
    }
    print line
}
END {
    if (operation == "modules") {
        print "i2c-dev"
    } else if (operation == "retroarch") {
        print "crt_switch_resolution = \"" mode "\""
        print "crt_switch_resolution_super = \"" (mode == "0" ? "0" : "1920") "\""
    } else {
        if (section != "[all]") print "[all]"
        if (operation == "audio") {
            audio(0)
        } else {
            print "# BEGIN JammaPi"
            print "hdmi_force_hotplug=1"
            print "dtparam=i2c_vc=on"
            audio(mode == "HDMI")
            setting("dtoverlay", "vga666,mode6", mode == "HDMI")
            setting("enable_dpi_lcd", "1", mode == "HDMI")
            setting("display_default_lcd", "1", mode == "HDMI")
            setting("dpi_output_format", "6", mode == "HDMI")
            setting("dpi_group", "2", mode == "HDMI")
            setting("dpi_mode", "87", mode == "HDMI")
            setting("hdmi_timings", "480 1 14 45 56 300 1 10 5 5 0 0 0 60 0 9600000 1", mode == "HDMI")
            print "#" mode
            print "# END JammaPi"
        }
    }
}
' "$file" > "$temporary"

if cmp -s "$temporary" "$file"; then
    exit 0
else
    status=$?
    if [ "$status" -ne 1 ]; then
        echo "Cannot compare configuration: $file" >&2
        exit "$status"
    fi
fi

# Keep ownership, permissions and symlinks of the target configuration.
cat "$temporary" > "$file"
