#!/bin/bash
# Build KlipperSnapmakerJ1-os for the J1 display module
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: ./build.sh DUMP [J1_REPO]
#   DUMP     full eMMC dump of your display module (sc20w-emmc-full.bin)
#   J1_REPO  checkout of KlipperSnapmakerJ1 (default ../KlipperSnapmakerJ1)
#
# Requirements: Docker and a qemu-arm binfmt handler (qemu-user-static).
# Results in out/: lk2nd.img (boot partition), linux-boot.img (cache
# partition) and userdata.img (userdata partition); see docs/INSTALL.md.
set -e

DUMP="$(realpath "$1")"
REPO="$(cd "$(dirname "$0")" && pwd)"
J1="$(realpath "${2:-$REPO/../KlipperSnapmakerJ1}")"
OUT="$REPO/out"
IMAGE_MIN_MB=3072

if [ ! -f "$DUMP" ] || [ ! -f "$J1/install.sh" ]; then
    sed -n '8,14p' "$0"
    exit 1
fi
mkdir -p "$OUT"

echo "== Stock display application from the dump (calibration pictures)"
docker run --rm -v "$(dirname "$DUMP"):/dump:ro" -v "$REPO:/repo:ro" \
    -v "$OUT:/out" debian:bookworm bash -e -c "
apt-get -qq update
apt-get -qq install -y --no-install-recommends python3 e2fsprogs > /dev/null
python3 /repo/tools/extract_stock.py '/dump/$(basename "$DUMP")' /out/stock
"

echo "== lk2nd and kernel"
"$REPO/boot/build.sh" "$OUT/boot"

echo "== Root file system"
"$REPO/rootfs/build.sh" "$OUT/boot" "$J1" "$OUT" "$OUT/stock/base.apk"

echo "== Partition images"
docker run --rm -v "$REPO:/repo:ro" -v "$OUT:/out" debian:bookworm \
    bash -e -c "
apt-get -qq update
apt-get -qq install -y --no-install-recommends e2fsprogs > /dev/null
cd /out
cp boot/lk2nd.img lk2nd.img
# Boot file system for the cache partition (lk2nd reads ext2)
mkdir -p /build/bootfs/extlinux
cp boot/zImage boot/snapmakerj1.dtb /build/bootfs/
cp /repo/boot/extlinux.conf /build/bootfs/extlinux/
rm -f linux-boot.img
mke2fs -q -t ext2 -L linux_boot -d /build/bootfs linux-boot.img 64M
e2fsck -fn linux-boot.img > /dev/null

mkdir -p /build/rootfs
tar -C /build/rootfs --numeric-owner -xf rootfs.tar
used=\$(du -sm /build/rootfs | cut -f1)
size=\$((used * 5 / 4 + 512))
[ \$size -lt $IMAGE_MIN_MB ] && size=$IMAGE_MIN_MB
rm -f userdata.img
mke2fs -q -t ext4 -L klipper-os -d /build/rootfs userdata.img \${size}M
e2fsck -fn userdata.img > /dev/null
ls -l lk2nd.img linux-boot.img userdata.img
"
echo "Done: $OUT/lk2nd.img $OUT/linux-boot.img $OUT/userdata.img"
