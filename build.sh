#!/bin/bash
# Build KlipperSnapmakerJ1-os: boot.img and userdata.img for the J1 display
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
# Results in out/: boot.img (signed for the stock bootloader) and
# userdata.img (root file system); see docs/INSTALL.md.
set -e

DUMP="$(realpath "$1")"
REPO="$(cd "$(dirname "$0")" && pwd)"
J1="$(realpath "${2:-$REPO/../KlipperSnapmakerJ1}")"
OUT="$REPO/out"
# Public AOSP test key trusted by the stock bootloader (docs/ANALYSIS.md)
AOSP_KEYS=https://android.googlesource.com/platform/build/+/refs/heads
AOSP_KEYS=$AOSP_KEYS/android11-release/target/product/security
VERITY_PK8_SHA256=75b2553350ae99867440c036edfb6262d34f878a733bc1a82990c01ef3e44145
VERITY_PEM_SHA256=ea9e433bb502a3ddef2c85460b499ab1bf8b2ff3f776b468199e5aa358932d9c
IMAGE_MIN_MB=3072

if [ ! -f "$DUMP" ] || [ ! -f "$J1/install.sh" ]; then
    sed -n '4,15p' "$0"
    exit 1
fi
mkdir -p "$OUT"

echo "== Stock parts from the dump"
docker run --rm -v "$(dirname "$DUMP"):/dump:ro" -v "$REPO:/repo:ro" \
    -v "$OUT:/out" debian:bookworm bash -e -c "
apt-get -qq update
apt-get -qq install -y --no-install-recommends python3 e2fsprogs > /dev/null
python3 /repo/tools/extract_stock.py '/dump/$(basename "$DUMP")' /out/stock
"

echo "== Initramfs"
"$REPO/initramfs/build.sh" "$OUT/initramfs.cpio.gz"

echo "== Root file system"
"$REPO/rootfs/build.sh" "$OUT/stock" "$J1" "$OUT"

echo "== boot.img and userdata.img"
docker run --rm -v "$REPO:/repo:ro" -v "$OUT:/out" debian:bookworm \
    bash -e -c "
apt-get -qq update
apt-get -qq install -y --no-install-recommends python3 python3-cryptography \
    e2fsprogs curl ca-certificates > /dev/null
cd /out
mkdir -p keys
for f in verity.pk8 verity.x509.pem; do
    [ -s keys/\$f ] || curl -sf '$AOSP_KEYS'/\$f?format=TEXT | base64 -d \
        > keys/\$f
done
echo '$VERITY_PK8_SHA256  keys/verity.pk8' | sha256sum -c --quiet
echo '$VERITY_PEM_SHA256  keys/verity.x509.pem' | sha256sum -c --quiet
python3 /repo/tools/bootimg.py unpack stock/boot.img stock/boot > /dev/null
python3 /repo/tools/bootimg.py pack --header stock/boot/header.json \
    --kernel stock/boot/kernel --ramdisk initramfs.cpio.gz boot-unsigned.img
python3 /repo/tools/boot_signer.py boot-unsigned.img keys/verity.pk8 \
    keys/verity.x509.pem boot.img
rm boot-unsigned.img

mkdir -p /build/rootfs
tar -C /build/rootfs --numeric-owner -xf rootfs.tar
used=\$(du -sm /build/rootfs | cut -f1)
size=\$((used * 5 / 4 + 512))
[ \$size -lt $IMAGE_MIN_MB ] && size=$IMAGE_MIN_MB
rm -f userdata.img
# Features of the stock kernel 3.10 only (no metadata_csum, orphan_file)
mke2fs -q -t ext4 -L klipper-os \
    -O ^metadata_csum,^metadata_csum_seed,^orphan_file,^64bit \
    -d /build/rootfs userdata.img \${size}M
e2fsck -fn userdata.img > /dev/null
ls -l boot.img userdata.img
"
echo "Done: $OUT/boot.img $OUT/userdata.img"
