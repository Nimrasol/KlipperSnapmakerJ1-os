#!/bin/bash
# Build and sign the installer apps: the trigger app (installed by the stock
# USB-update flow as com.snapmaker.j1) installs and starts the installer app,
# which hands the OTA to the recovery.
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: install/build-app.sh OTA_ZIP OUT_APK
#   OTA_ZIP   the signed OTA package (install/build-ota.sh), embedded in the
#             installer app so it does not have to find it on the stick
#   OUT_APK   the signed trigger APK (becomes entry type 3 of the package);
#             it embeds the installer app
#
# Requirements: apktool, java, curl.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
OTA="$(realpath "$1")"
OUT="$(realpath -m "$2")"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/j1-ota"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$OTA" ] || [ -z "$2" ]; then
    sed -n '8,12p' "$0"
    exit 1
fi

# The public AOSP platform key, which also signs the stock app and the
# system: the trigger replaces the stock app, the installer app joins the
# system user id.
# (The OTA itself is signed with the test key, see build-ota.sh.)
mkdir -p "$CACHE"
gfetch() {
    [ -s "$CACHE/$2" ] && return 0
    curl -fsSL "https://android.googlesource.com/platform/$1?format=TEXT" \
        | base64 -d > "$CACHE/$2"
}
gfetch "build/+/refs/tags/android-7.1.2_r39/target/product/security/platform.x509.pem" platform.x509.pem
gfetch "build/+/refs/tags/android-7.1.2_r39/target/product/security/platform.pk8" platform.pk8
if [ ! -s "$CACHE/signapk.jar" ]; then
    curl -fsSL "https://android.googlesource.com/platform/prebuilts/sdk/+/refs/tags/android-6.0.1_r81/tools/lib/signapk.jar?format=TEXT" \
        | base64 -d > "$CACHE/signapk.jar"
fi

# build_apk PROJECT ASSET_SRC ASSET_NAME OUT: apktool project with one
# asset, signed with the platform key
build_apk() {
    rm -rf "$WORK/proj"
    cp -r "$HERE/$1" "$WORK/proj"
    mkdir -p "$WORK/proj/assets"
    cp "$2" "$WORK/proj/assets/$3"
    echo "== apktool build $1"
    apktool b -o "$WORK/unsigned.apk" "$WORK/proj"
    echo "== sign $1 (public AOSP platform key)"
    mkdir -p "$(dirname "$4")"
    java -Xmx512m -jar "$CACHE/signapk.jar" \
        "$CACHE/platform.x509.pem" "$CACHE/platform.pk8" "$WORK/unsigned.apk" "$4"
}

build_apk installer-app "$OTA" klipper-ota.zip "$WORK/installer.apk"
build_apk trigger-app "$WORK/installer.apk" installer.apk "$OUT"

echo "== result"
aapt dump badging "$OUT" | grep -E "package|application-label|uses-permission|launchable" || true
echo "APK: $OUT ($(stat -c %s "$OUT") bytes)"
