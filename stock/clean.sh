#!/bin/bash
# Remove the personal and device specific data from a mounted Android
# userdata file system, so that it can be restored on any J1.  Android
# creates everything removed here again on the next start, as after a
# factory reset.
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: clean.sh MOUNTPOINT
set -e
cd "$1"

# Overwrite a file in place: keeps owner, mode and SELinux label
rewrite() {
    "$@" < "$F" > /tmp/rewrite
    cat /tmp/rewrite > "$F"
}

# Snapmaker app: print files, thumbnails, logs, analytics
A=data/com.snapmaker.j1
rm -rf $A/files/* $A/files/.com.google.firebase.crashlytics $A/cache/*
rm -f $A/databases/*
rm -f $A/shared_prefs/com.google.* $A/shared_prefs/FirebaseAppHeartBeat.xml
rm -rf media/0/Android/data/com.snapmaker.j1/cache
printf "{}" > $A/wifi_info
F=$A/shared_prefs/com.snapmaker.fabscreen.PREFERENCE_DEFAULT.xml
rewrite python3 -c '
import re, sys
s = sys.stdin.read()
# Last WLAN, machine name and the last print job
s = re.sub(r"(<string name=\"(LAST_CONNECTED_AP_PWD|LAST_CONNECTED_AP_SSID"
           r"|MACHINE_NAME|FILE_PATH)\">)[^<]*(</string>)", r"\1\3", s)
s = re.sub(r"<set name=\"REMOTE_TOKEN\">.*?</set>",
           "<set name=\"REMOTE_TOKEN\" />", s, flags=re.S)
s = re.sub(r"(name=\"(PRINT_ELAPSED_TIME|FILE_TOTAL_LINES)\" value=)\"[^\"]*\"",
           r"\g<1>" + "\"0\"", s)
s = re.sub(r"(name=\"FILE_ESTIMATED_TIME\" value=)\"[^\"]*\"",
           r"\g<1>" + "\"0.0\"", s)
# Setup and calibration guide as on the first start of a new printer
s = re.sub(r"(name=\"MACHINE_SETUP_(FLAG|LANGUAGE|3DP)\" value=)\"true\"",
           r"\g<1>" + "\"false\"", s)
sys.stdout.write(s)
'

# WLAN: networks, calibration, IP settings, hotspot, location cache
F=misc/wifi/wpa_supplicant.conf
rewrite sed '/^network={/,/^}/d'
: > misc/wifi/networkHistory.txt
rm -f misc/wifi/WCNSS_qcom_wlan_cal.bin misc/wifi/ipconfig.txt
rm -f misc/wifi/softap.conf misc/wifi/entropy.bin
rm -rf misc/location/xtwifi/*

# Bluetooth address, Android ID
rm -f misc/bluedroid/*
F=system/users/0/settings_secure.xml
rewrite grep -v -E 'name="(android_id|bluetooth_address|bluetooth_addr_valid|bluetooth_name)"'

# Usage statistics, crash reports, logs, media index
rm -rf system/dropbox/* system/usagestats/* system/procstats/*
rm -rf system/netstats/* system_ce/0/recent_tasks/*
rm -f system/notification_log.db*
rm -f data/com.innopath.activecare/files/app_log.txt
rm -f data/com.innopath.activecare/app_dme/dme_log.txt*
rm -f data/com.android.providers.media/databases/*

# Check: no print files, no WLAN networks, no personal values left
left() {
    if "$@"; then
        echo "clean: still there: ${*: -1}" >&2
        exit 1
    fi
}
left sh -c 'find . -iname "*.gcode" | grep -q .' gcode
left grep -q "network=" misc/wifi/wpa_supplicant.conf
F=$A/shared_prefs/com.snapmaker.fabscreen.PREFERENCE_DEFAULT.xml
left grep -q -E '"(LAST_CONNECTED_AP_PWD|LAST_CONNECTED_AP_SSID|MACHINE_NAME|FILE_PATH)">[^<]' $F
left grep -q '<string>.' $F
# Android drops a preferences file it cannot parse (all settings lost)
python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' \
    $F || { echo "clean: no valid XML: $F" >&2; exit 1; }
left grep -q '"android_id"' system/users/0/settings_secure.xml
echo "clean: ok"
