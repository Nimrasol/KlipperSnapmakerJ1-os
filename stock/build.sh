#!/bin/bash
# Build the USB stick contents to return a J1 to the Snapmaker system
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: stock/build.sh DUMP PACKAGE
#   DUMP     full eMMC dump of a display module with the Snapmaker system
#   PACKAGE  official Snapmaker update package (eg J1_V2.8.0_20251217.bin)
#
# Requirements: Docker (privileged containers, for loop mounts).
# Result: out/J1-Stock-Firmware-<package>.zip with the package, the
# cleaned Snapmaker system in stock-restore/ and a README.
set -e

DUMP="$(realpath "$1")"
PACKAGE="$(realpath "$2")"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/out/stock"
NAME="$(basename "$PACKAGE" .bin)"

if [ ! -f "$DUMP" ] || [ ! -f "$PACKAGE" ]; then
    sed -n '8,10p' "$0"
    exit 1
fi
rm -rf "$OUT"
mkdir -p "$OUT/stick/stock-restore"

docker run --rm --privileged -v "$(dirname "$DUMP"):/dump:ro" \
    -v "$REPO:/repo:ro" -v "$OUT:/out" debian:bookworm bash -e -c "
apt-get -qq update
apt-get -qq install -y --no-install-recommends python3 e2fsprogs zerofree \
    util-linux > /dev/null
# Work in the container: on a Windows drive (WSL) the holes of sparse
# files did not always read back as zeros
mkdir -p /work
cd /work
DUMP='/dump/$(basename "$DUMP")'
eval \$(python3 -c '
import sys
sys.path.insert(0, \"/repo/tools\")
from extract_stock import read_gpt
parts = read_gpt(open(sys.argv[1], \"rb\"))
for name in (\"boot\", \"cache\", \"userdata\"):
    print(\"%s_off=%d %s_size=%d\" % (name, parts[name][\"offset\"],
                                    name, parts[name][\"size\"]))
' \"\$DUMP\")
S=/out/stick/stock-restore

# Boot image and encryption footer as they are
dd if=\"\$DUMP\" of=\$S/boot.img iflag=skip_bytes,count_bytes \
    skip=\$boot_off count=\$boot_size status=none
dd if=\"\$DUMP\" of=\$S/userdata-footer.bin iflag=skip_bytes,count_bytes \
    skip=\$((userdata_off + userdata_size - 16384)) count=16384 status=none

# File systems: only the used blocks, then cleaned
e2image -ra -o \$userdata_off \"\$DUMP\" userdata.img
e2image -ra -o \$cache_off \"\$DUMP\" cache.img
for img in userdata.img cache.img; do
    e2fsck -fy \$img > /dev/null || [ \$? -le 1 ]
done
mkdir -p /m
mount -o loop userdata.img /m
bash /repo/stock/clean.sh /m
umount /m

# A new journal and zeroed free blocks: nothing removed stays readable
for img in userdata.img cache.img; do
    info=\$(dumpe2fs -h \$img 2>/dev/null)
    blocks=\$(echo \"\$info\" | sed -n 's/^Total journal blocks: *//p')
    bsize=\$(echo \"\$info\" | sed -n 's/^Block size: *//p')
    tune2fs -O ^has_journal \$img > /dev/null
    zerofree \$img
    tune2fs -j -J size=\$((blocks * bsize >> 20)) \$img > /dev/null
    e2fsck -fn \$img > /dev/null
    python3 /repo/stock/check_free.py \$img
done
gzip -6 -c userdata.img > \$S/userdata.img.gz
gzip -6 -c cache.img > \$S/cache.img.gz
rm userdata.img cache.img
cd \$S
sha256sum boot.img userdata.img.gz userdata-footer.bin cache.img.gz > manifest
"

cp "$PACKAGE" "$OUT/stick/"
sed 's/$/\r/' "$REPO/stock/README.txt" > "$OUT/stick/README-Stock-Firmware.txt"
ZIP="$REPO/out/J1-Stock-Firmware-$NAME.zip"
rm -f "$ZIP"
(cd "$OUT/stick" && zip -q -r -0 "$ZIP" .)
ls -l "$ZIP"
cat "$OUT/stick/stock-restore/manifest"
