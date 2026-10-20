#!/bin/bash
# Build the Debian root file system of KlipperSnapmakerJ1-os
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: rootfs/build.sh STOCK_DIR J1_REPO OUT_DIR
#   STOCK_DIR  output of tools/extract_stock.py (WLAN driver, firmware)
#   J1_REPO    checkout of KlipperSnapmakerJ1 to install
#   OUT_DIR    receives rootfs.tar
#
# Runs in a privileged Debian container; the armhf programs of the new
# system run through the qemu binfmt handler of the build host.
set -e

STOCK="$(realpath "$1")"
J1="$(realpath "$2")"
OUT="$(realpath -m "$3")"
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

if [ ! -e /proc/sys/fs/binfmt_misc/qemu-arm ]; then
    echo "The build host needs a qemu-arm binfmt handler (qemu-user-static)"
    exit 1
fi

docker run --rm --privileged \
    -v "$SRC:/src:ro" -v "$STOCK:/stock:ro" -v "$J1:/j1:ro" -v "$OUT:/out" \
    debian:bookworm bash -e -c '
apt-get -qq update
apt-get -qq install -y --no-install-recommends mmdebstrap arch-test \
    qemu-user-static gpg ca-certificates git \
    > /dev/null
# Built inside the container: the output directory may be on a file
# system without device nodes and owners (eg a Windows drive under WSL)
root=/build/rootfs
mkdir -p $root
# No recommends, and sysvinit instead of systemd (see packages.txt)
mmdebstrap --architectures=armhf --variant=minbase \
    --aptopt="APT::Install-Recommends \"false\"" \
    --aptopt="APT::Install-Suggests \"false\"" \
    --include="$(grep -v "^#" /src/packages.txt | tr "\n" " " \
        | tr -s " " | sed "s/ /,/g; s/,$//")" \
    bookworm $root http://deb.debian.org/debian
# Owned by root with default modes (the source may be a Windows drive)
cp -r --no-preserve=mode,ownership /src/overlay/. $root/
chmod 0755 $root/etc/init.d/j1-* $root/usr/local/sbin/*
# Stock parts of the display module (not distributed with this project)
install -D -m 0644 /stock/system/lib/modules/pronto/pronto_wlan.ko \
    $root/lib/modules/3.10.49/pronto_wlan.ko
install -D -m 0644 /stock/system/etc/firmware/wlan/prima/WCNSS_cfg.dat \
    $root/lib/firmware/wlan/prima/WCNSS_cfg.dat
install -D -m 0644 /stock/system/etc/wifi/WCNSS_qcom_cfg.ini \
    $root/lib/firmware/wlan/prima/WCNSS_qcom_cfg.ini
ln -sf /persist/WCNSS_qcom_wlan_nv.bin \
    $root/lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin
# A clean clone of the last commit (Moonraker refuses to update a
# modified checkout)
git config --global --add safe.directory "*"
git clone -q /j1 $root/opt/KlipperSnapmakerJ1
# Stock display application: pictures and test prints of the calibration
[ -e /stock/base.apk ] && cp /stock/base.apk $root/tmp/base.apk
cp /src/setup.sh $root/tmp/setup.sh
cp /src/fb-refresher.c $root/tmp/fb-refresher.c
mount -t proc proc $root/proc
mount -t sysfs sysfs $root/sys
mount --bind /dev $root/dev
cp /etc/resolv.conf $root/etc/resolv.conf
trap "umount $root/proc $root/sys $root/dev" EXIT
chroot $root /bin/bash /tmp/setup.sh
rm -f $root/tmp/setup.sh $root/tmp/fb-refresher.c
umount $root/proc $root/sys $root/dev
trap - EXIT
echo "nameserver 1.1.1.1" > $root/etc/resolv.conf
tar -C $root --numeric-owner -cf /out/rootfs.tar .
du -sh $root
'
echo "$OUT/rootfs.tar"
