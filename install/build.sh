#!/bin/bash
# Build the USB stick contents that install KlipperSnapmakerJ1-os on a
# Snapmaker J1 running the stock Snapmaker system - no EDL, no opening the
# printer.
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: install/build.sh OSOUT STOCK_PACKAGE OUTDIR
#   OSOUT          the out/ directory of a KlipperSnapmakerJ1-os build
#                  (boot/zImage, boot/snapmakerj1.dtb, boot/modules/,
#                  lk2nd.img, userdata.img)
#   STOCK_PACKAGE  an official Snapmaker update package (J1_V*.bin); its
#                  genuine main controller firmware is reused so the stock
#                  update flow runs normally
#   OUTDIR         where to write the stick/ tree and the .zip
#
# The resulting stick carries:
#   J1_V*.bin          stock main controller + the installer app (the stock
#                      USB update installs and launches it)
#   install/lk2nd.img      boot loader           ) written by the OTA that
#   install/linux-boot.img Linux boot (install)  ) the installer app starts
#   install/rootfs.img.gz  Klipper root fs        ) written by maint
#   install/manifest       sha256 of the above
#
# Requirements: Docker, arm-linux-gnueabihf-gcc, apktool, java, curl, zip.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
OSOUT="$(realpath "$1")"
STOCK="$(realpath "$2")"
OUTDIR="$(realpath -m "$3")"
BUILD="$OUTDIR/build"

for f in boot/zImage boot/snapmakerj1.dtb boot/modules lk2nd.img userdata.img; do
    [ -e "$OSOUT/$f" ] || { echo "missing $OSOUT/$f"; sed -n '9,16p' "$0"; exit 1; }
done
[ -f "$STOCK" ] || { echo "missing $STOCK"; exit 1; }
rm -rf "$BUILD"; mkdir -p "$BUILD" "$OUTDIR/stick/install"
STICK="$OUTDIR/stick"

echo "== 1/7  maintenance system (install mode)"
"$REPO/maint/build.sh" "$OSOUT/boot" "$BUILD/maint.cpio.gz"

echo "== 2/7  linux-boot image in install mode (default=maint, request=install)"
# extlinux that boots maint by default; maint sees request=install
sed 's/^default .*/default maint/' "$REPO/boot/extlinux.conf" > "$BUILD/extlinux.conf"
docker run --rm -v "$BUILD:/b" -v "$OSOUT:/os:ro" debian:bookworm bash -e -c '
apt-get -qq update; apt-get -qq install -y --no-install-recommends e2fsprogs > /dev/null
root=/b/bootfs
mkdir -p $root/extlinux $root/maint
cp /os/boot/zImage /os/boot/snapmakerj1.dtb /b/maint.cpio.gz $root/
cp /b/extlinux.conf $root/extlinux/extlinux.conf
printf install > $root/maint/request
rm -f /b/linux-boot.img
mke2fs -q -t ext2 -L linux_boot -d $root /b/linux-boot.img 64M
e2fsck -fn /b/linux-boot.img > /dev/null
'
cp "$OSOUT/lk2nd.img" "$STICK/install/lk2nd.img"
cp "$BUILD/linux-boot.img" "$STICK/install/linux-boot.img"

echo "== 3/7  OTA package (signed, recovery-trusted test key)"
"$HERE/build-ota.sh" "$STICK/install/lk2nd.img" "$STICK/install/linux-boot.img" \
    "$BUILD/klipper-ota.zip"

echo "== 4/7  installer app (platform-key signed)"
"$HERE/build-app.sh" "$BUILD/klipper-ota.zip" "$BUILD/trigger.apk"

echo "== 5/7  Snapmaker update package (stock MC + installer app)"
NAME="$(basename "$STOCK")"
python3 "$HERE/build-package.py" "$STOCK" "$BUILD/trigger.apk" "$STICK/$NAME"

echo "== 6/7  Klipper root file system for the stick"
gzip -6 -c "$OSOUT/userdata.img" > "$STICK/install/rootfs.img.gz"
( cd "$STICK/install" && sha256sum lk2nd.img linux-boot.img rootfs.img.gz > manifest )

echo "== 7/7  README and zip"
sed 's/$/\r/' "$HERE/README.txt" > "$STICK/README-Install-Klipper.txt"
ZIP="$OUTDIR/KlipperSnapmakerJ1-install.zip"
rm -f "$ZIP"
( cd "$STICK" && zip -q -r -0 "$ZIP" . )
echo
echo "stick tree: $STICK"
ls -la "$STICK" "$STICK/install"
echo "zip: $ZIP ($(stat -c %s "$ZIP") bytes)"
