#!/bin/bash
# Build the Debian root file system of KlipperSnapmakerJ1-os
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: rootfs/build.sh BOOT_DIR J1_REPO OUT_DIR [APK]
#   BOOT_DIR   output of boot/build.sh (kernel modules and release)
#   J1_REPO    checkout of KlipperSnapmakerJ1 to install
#   OUT_DIR    receives rootfs.tar
#   APK        stock display application (calibration pictures), optional
#
# Runs in a privileged Debian container; the armhf programs of the new
# system run through the qemu binfmt handler of the build host.
set -e

BOOT="$(realpath "$1")"
J1="$(realpath "$2")"
OUT="$(realpath -m "$3")"
APK="${4:+$(realpath "$4")}"
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

if [ ! -e /proc/sys/fs/binfmt_misc/qemu-arm ]; then
    echo "The build host needs a qemu-arm binfmt handler (qemu-user-static)"
    exit 1
fi
APK_MOUNT=
[ -n "$APK" ] && APK_MOUNT="-v $APK:/apk/base.apk:ro"

docker run --rm --privileged \
    -v "$SRC:/src:ro" -v "$BOOT:/boot-out:ro" -v "$J1:/j1:ro" \
    -v "$OUT:/out" $APK_MOUNT \
    debian:bookworm bash -e -c '
apt-get -qq update
apt-get -qq install -y --no-install-recommends mmdebstrap arch-test \
    qemu-user-static gpg ca-certificates git \
    > /dev/null
# Built inside the container: the output directory may be on a file
# system without device nodes and owners (eg a Windows drive under WSL)
root=/build/rootfs
mkdir -p $root
mmdebstrap --architectures=armhf --variant=minbase \
    --aptopt="APT::Install-Recommends \"false\"" \
    --aptopt="APT::Install-Suggests \"false\"" \
    --include="$(grep -v "^#" /src/packages.txt | tr "\n" " " \
        | tr -s " " | sed "s/ /,/g; s/,$//")" \
    bookworm $root http://deb.debian.org/debian
# Owned by root with default modes (the source may be a Windows drive)
cp -r --no-preserve=mode,ownership /src/overlay/. $root/
cp -r --no-preserve=mode,ownership /boot-out/modules/lib/modules $root/lib/
cp /boot-out/kernelrelease $root/tmp/kernelrelease
cp /boot-out/versions $root/tmp/boot-versions
# A clean clone of the last commit (Moonraker refuses to update a
# modified checkout)
git config --global --add safe.directory "*"
git clone -q /j1 $root/opt/KlipperSnapmakerJ1
[ -e /apk/base.apk ] && cp /apk/base.apk $root/tmp/base.apk
cp /src/setup.sh $root/tmp/setup.sh
mount -t proc proc $root/proc
mount -t sysfs sysfs $root/sys
mount --bind /dev $root/dev
cp /etc/resolv.conf $root/etc/resolv.conf
trap "umount $root/proc $root/sys $root/dev" EXIT
chroot $root /bin/bash /tmp/setup.sh
rm -f $root/tmp/setup.sh $root/tmp/kernelrelease $root/tmp/boot-versions
umount $root/proc $root/sys $root/dev
trap - EXIT
# NetworkManager writes resolv.conf at runtime
rm -f $root/etc/resolv.conf
tar -C $root --numeric-owner -cf /out/rootfs.tar .
du -sh $root
'
echo "$OUT/rootfs.tar"
