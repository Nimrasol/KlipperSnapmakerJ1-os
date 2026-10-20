#!/bin/bash
# Build the initramfs (static busybox and init) as a gzip compressed cpio
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: initramfs/build.sh OUT.cpio.gz
# Runs in Docker (Debian bookworm, armhf busybox-static).
set -e

OUT="$(realpath -m "$1")"
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$(dirname "$OUT")"

docker run --rm -v "$SRC:/src:ro" -v "$(dirname "$OUT"):/out" \
    -e OUT_NAME="$(basename "$OUT")" debian:bookworm bash -e -c '
dpkg --add-architecture armhf
apt-get -qq update
apt-get -qq install -y --no-install-recommends cpio > /dev/null
cd /tmp
apt-get -qq download busybox-static:armhf
dpkg-deb -x busybox-static_*_armhf.deb pkg
root=/tmp/initramfs
mkdir -p $root/bin $root/sbin $root/dev $root/proc $root/sys $root/run \
    $root/newroot
cp pkg/bin/busybox $root/bin/busybox
# The applets the init script uses
for applet in sh mount umount mknod mkdir sed grep cat echo sleep ifconfig \
        telnetd switch_root mdev ls ln rm cp dmesg ps kill vi; do
    ln -s busybox $root/bin/$applet
done
ln -s ../bin/busybox $root/sbin/mdev
ln -s ../bin/busybox $root/sbin/switch_root
install -m 0755 /src/init $root/init
# Every applet must exist in this busybox build
for applet in mdev switch_root telnetd ifconfig; do
    $root/bin/busybox --list | grep -qx $applet ||
        { echo "busybox lacks $applet"; exit 1; }
done
cd $root
find . | sort | cpio -o -H newc --quiet | gzip -9 > /out/$OUT_NAME
'
echo "$OUT: $(stat -c %s "$OUT") bytes"
