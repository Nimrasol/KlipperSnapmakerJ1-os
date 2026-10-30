#!/bin/bash
# Build the maintenance system (initramfs) of KlipperSnapmakerJ1-os
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: maint/build.sh BOOT_DIR OUT_FILE
#   BOOT_DIR   output of boot/build.sh (kernel modules for the USB stick)
#   OUT_FILE   initramfs (gzip compressed cpio), eg out/maint.cpio.gz
#
# The initramfs holds the static busybox of Debian (armhf), the SCSI disk
# and code page modules for the USB stick and maint/init.  It runs
# with the kernel of the image (lk2nd label "maint" in extlinux.conf).
set -e

BOOT="$(realpath "$1")"
OUT="$(realpath -m "$2")"
SRC="$(cd "$(dirname "$0")" && pwd)"
[ -d "$BOOT/modules" ] || { sed -n '8,10p' "$0"; exit 1; }
mkdir -p "$(dirname "$OUT")"

docker run --rm -v "$SRC:/src:ro" -v "$BOOT:/boot-out:ro" \
    -v "$(dirname "$OUT"):/out" debian:bookworm bash -e -c "
dpkg --add-architecture armhf
apt-get -qq update
apt-get -qq install -y --no-install-recommends cpio zstd > /dev/null
cd /tmp
apt-get -qq download busybox-static:armhf
root=/tmp/root
mkdir -p \$root/bin \$root/sbin \$root/lib/modules
dpkg-deb -x busybox-static_*_armhf.deb /tmp/bb
cp /tmp/bb/bin/busybox \$root/bin/busybox
# The applets as links (the list through the qemu binfmt handler of the
# build host, or the applets maint/init uses), the SCSI disk driver and
# the code pages for vfat (built as modules; udev loads them in the Linux
# system)
for a in \$(/tmp/bb/bin/busybox --list 2>/dev/null \
        || echo sh [ test mount umount cat sed grep printf sleep insmod \
             dd gunzip sha256sum cmp wc mkdir reboot ls true); do
    [ \$a = busybox ] || ln -sf busybox \$root/bin/\$a
done
for m in sd_mod nls_cp437 nls_iso8859-1; do
    f=\$(find /boot-out/modules -name \"\$m.ko*\" | head -n 1)
    case \"\$f\" in
        *.zst) zstd -q -d \"\$f\" -o \$root/lib/modules/\$m.ko ;;
        *) cp \"\$f\" \$root/lib/modules/\$m.ko ;;
    esac
done
install -m 0755 /src/init \$root/init
(cd \$root && find . | cpio -o -H newc --quiet | gzip -9) > /out/$(basename "$OUT")
ls -l /out/$(basename "$OUT")
"
