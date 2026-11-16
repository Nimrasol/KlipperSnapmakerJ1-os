#!/bin/bash
# Test of maint/init: what the next start does after each way out
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: maint/test.sh        (needs Docker; runs in a Debian container)
#
# Each case runs maint/init with busybox in a chroot with fake partitions,
# sysfs and USB stick; mount, reboot and sleep are stubs.  Checked: the
# default of extlinux.conf, the request, and how init ended (reboot, or
# halted with an error message).
set -e

if [ "$1" != --inside ]; then
    SRC="$(cd "$(dirname "$0")" && pwd)"
    exec docker run --rm -v "$SRC:/src:ro" debian:bookworm \
        bash /src/test.sh --inside
fi

apt-get -qq update
apt-get -qq install -y --no-install-recommends busybox-static > /dev/null
# The Klipper system of the stick: 1 MiB that does not compress
head -c 1048576 /dev/urandom > /tmp/rootfs.img

# setup ROOT REQUEST STICK(none|ok|badsum|truncated)
setup() {
    local r=$1
    rm -rf "$r"
    mkdir -p "$r"/bin "$r"/proc "$r"/dev "$r"/tmp "$r"/lib/modules \
        "$r"/mnt/stick "$r"/mnt/cache/extlinux "$r"/mnt/cache/maint
    cp /bin/busybox "$r"/bin/busybox
    for a in $(/bin/busybox --list); do
        [ "$a" = busybox ] || ln -sf busybox "$r/bin/$a"
    done
    stub() { rm -f "$r/bin/$1"; printf '#!/bin/sh\n%s\n' "$2" > "$r/bin/$1"; chmod +x "$r/bin/$1"; }
    stub mount 'case "$*" in *vfat*) [ -e /stick-present ] ;; *) exit 0 ;; esac'
    stub umount 'exit 0'
    stub insmod 'exit 0'
    stub dmesg 'exit 0'
    # The end of init: a reboot, or the endless wait after an error
    stub reboot 'echo reboot > /result; kill -9 $PPID'
    stub sleep '[ "$1" = 3600 ] || exit 0; echo halt > /result; kill -9 $PPID'
    cp /src/init "$r/init"

    echo "0.00 0.00" > "$r/proc/uptime"
    : > "$r/proc/partitions"
    : > "$r/dev/tty1"
    mknod "$r/dev/sda1" b 8 1
    local n=1
    for p in cache userdata boot; do
        mkdir -p "$r/sys/class/block/mmcblk0p$n"
        printf 'DEVNAME=mmcblk0p%s\nPARTNAME=%s\n' $n $p \
            > "$r/sys/class/block/mmcblk0p$n/uevent"
        echo 8192 > "$r/sys/class/block/mmcblk0p$n/size"
        : > "$r/dev/mmcblk0p$n"
        n=$((n + 1))
    done
    printf 'default maint\nlabel j1\nlabel maint\n' \
        > "$r/mnt/cache/extlinux/extlinux.conf"
    [ -z "$2" ] || printf '%s' "$2" > "$r/mnt/cache/maint/request"
    # WRITTEN=1: an earlier restore run was cut after writing userdata
    [ -z "$WRITTEN" ] || touch "$r/mnt/cache/maint/written"

    [ "$3" = none ] && return 0
    touch "$r/stick-present"
    local s="$r/mnt/stick/install"
    mkdir -p "$s"
    gzip -c /tmp/rootfs.img > "$s/rootfs.img.gz"
    if [ "$3" = truncated ]; then
        head -c 500000 "$s/rootfs.img.gz" > /tmp/cut.gz
        mv /tmp/cut.gz "$s/rootfs.img.gz"
    fi
    (cd "$s" && sha256sum rootfs.img.gz > manifest)
    [ "$3" != badsum ] || echo x >> "$s/rootfs.img.gz"
    return 0
}

FAILED=0
# check NAME REQUEST STICK  END DEFAULT REQUEST_LEFT(yes|no)
check() {
    local r=/t/$1
    setup "$r" "$2" "$3"
    (timeout 60 chroot "$r" /bin/sh /init) 2> /dev/null || true
    local end def left=no
    end=$(cat "$r/result" 2>/dev/null || echo none)
    def=$(sed -n 's/^default //p' "$r/mnt/cache/extlinux/extlinux.conf")
    [ -e "$r/mnt/cache/maint/request" ] && left=yes
    if [ "$end $def $left" = "$4 $5 $6" ]; then
        echo "ok    $1"
    else
        echo "FAIL  $1: got end=$end default=$def request=$left," \
             "want end=$4 default=$5 request=$6"
        sed 's/^/      | /' "$r/dev/tty1"
        FAILED=1
    fi
}

#     name                 request  stick      end     default  request
check install-no-stick     install  none       halt    maint    yes
check install-bad-sum      install  badsum     halt    maint    yes
check install-stick-error  install  truncated  halt    maint    yes
check install-ok           install  ok         reboot  j1       no
check restore-no-stick     restore  none       reboot  j1       yes
WRITTEN=1 check restore-cut-no-stick \
                           restore  none       halt    maint    yes
check no-request           ""       none       reboot  j1       no

# The Klipper system lands on userdata as it is
cmp /tmp/rootfs.img /t/install-ok/dev/mmcblk0p2 && echo "ok    install-ok writes userdata" \
    || { echo "FAIL  install-ok: userdata differs from the image"; FAILED=1; }
exit $FAILED
