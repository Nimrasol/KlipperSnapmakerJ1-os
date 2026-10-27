#!/bin/bash
# Set up the root file system (runs inside the armhf chroot)
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Installs Klipper, Moonraker, KlipperScreen and KlipperSnapmakerJ1 for the
# user pi and enables the services.
set -e
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
PIP_INDEX="--extra-index-url https://www.piwheels.org/simple"
HOME_DIR=/home/pi
J1=$HOME_DIR/KlipperSnapmakerJ1
# Mainsail release in the image; Moonraker updates it afterwards
MAINSAIL_VERSION=v2.19.0

# Locale and time zone
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen > /dev/null
echo 'LANG="en_US.UTF-8"' > /etc/default/locale
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Kernel modules of the mainline kernel (boot/build.sh)
depmod -a "$(cat /tmp/kernelrelease)"

# User pi (password "klipper", change it after the first login)
useradd -m -s /bin/bash -G sudo,dialout,tty,video,input,netdev,render pi
echo "pi:klipper" | chpasswd
echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi
chmod 0440 /etc/sudoers.d/010_pi

# Created on the first boot of each device
rm -f /etc/ssh/ssh_host_*
: > /etc/machine-id
chmod 0755 /usr/local/sbin/j1-firstboot /usr/local/sbin/j1-chvt \
    /usr/local/bin/j1-session

# Services; nothing that waits for the network or runs maintenance jobs at
# boot (short boot time, the printer is switched off without shutdown)
systemctl enable klipper moonraker KlipperScreen seatd j1-firstboot \
    wcnss-firmware NetworkManager ssh systemd-timesyncd nginx \
    avahi-daemon fake-hwclock j1-clock-save.timer > /dev/null 2>&1
systemctl set-default multi-user.target > /dev/null
systemctl disable NetworkManager-wait-online.service > /dev/null 2>&1 || true
for unit in apt-daily.timer apt-daily-upgrade.timer man-db.timer \
            e2scrub_all.timer e2scrub_reap.service dpkg-db-backup.timer; do
    systemctl mask "$unit" > /dev/null 2>&1 || true
done

# Klipper, Moonraker and KlipperScreen at the versions KlipperSnapmakerJ1 is
# tested with (versions.conf): clones of their own repositories on the
# master branch, so that the update manager updates them as usual
cp -a /opt/KlipperSnapmakerJ1 $J1
rm -rf /opt/KlipperSnapmakerJ1
chown -R pi:pi $J1
su pi -c "
set -e
cd $HOME_DIR
git -C $J1 remote set-url origin \
    https://github.com/Nimrasol/KlipperSnapmakerJ1.git
grep -v '^#' $J1/versions.conf | while read name commit version date url; do
    [ -n \"\$name\" ] || continue
    git clone -q \$url \$name
    git -C \$name checkout -q -B master \$commit
    git -C \$name branch -q -u origin/master master
done

python3 -m venv klippy-env
klippy-env/bin/pip install -q $PIP_INDEX \
    -r klipper/scripts/klippy-requirements.txt
klippy-env/bin/python -c 'import sys; sys.path.insert(0, \"klipper/klippy\");
import chelper; chelper.get_ffi()'

python3 -m venv moonraker-env
moonraker-env/bin/pip install -q $PIP_INDEX \
    -r moonraker/scripts/moonraker-requirements.txt

# GTK and cairo come from Debian (python3-gi, python3-cairo)
python3 -m venv --system-site-packages .KlipperScreen-env
grep -viE '^(PyGObject|pycairo|python-mpv)' \
    KlipperScreen/scripts/KlipperScreen-requirements.txt \
    > /tmp/ks-requirements.txt
.KlipperScreen-env/bin/pip install -q $PIP_INDEX -r /tmp/ks-requirements.txt
rm /tmp/ks-requirements.txt

# Byte code now, not on the first start of each program
for d in klipper/klippy moonraker/moonraker KlipperScreen; do
    python3 -m compileall -q \$d > /dev/null || true
done

mkdir -p printer_data/config printer_data/logs printer_data/gcodes \
    printer_data/comms printer_data/database

# Mainsail (web interface, served by nginx)
curl -sfL -o /tmp/mainsail.zip \
    https://github.com/mainsail-crew/mainsail/releases/download/$MAINSAIL_VERSION/mainsail.zip
mkdir -p mainsail
unzip -q -o /tmp/mainsail.zip -d mainsail
rm /tmp/mainsail.zip
"

# nginx serves Mainsail instead of its default page
rm -f /etc/nginx/sites-enabled/default
ln -sf ../sites-available/mainsail /etc/nginx/sites-enabled/mainsail

# <name>.local resolves to the IPv4 address only: Moonraker trusts the
# local IPv4 networks, but not the public IPv6 address of a client, so
# uploads from a slicer over IPv6 were refused (401)
sed -i -e 's/^#\?use-ipv6=.*/use-ipv6=no/' \
    -e 's/^#\?publish-aaaa-on-ipv4=.*/publish-aaaa-on-ipv4=no/' \
    /etc/avahi/avahi-daemon.conf

# Moonraker: services through systemctl (pi may use sudo), no system
# package updates
cat > $HOME_DIR/printer_data/config/moonraker.conf <<'EOF'
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: ~/printer_data/comms/klippy.sock

[authorization]
trusted_clients:
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.168.0.0/16
    FE80::/10
    ::1/128
cors_domains:
    *.lan
    *.local
    *://localhost
    *://localhost:*
    *://my.mainsail.xyz
    *://app.fluidd.xyz

[octoprint_compat]

[history]

[machine]
provider: systemd_cli
validate_service: False

[update_manager]
refresh_interval: 168
enable_system_updates: False

[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: ~/mainsail

[update_manager KlipperScreen]
type: git_repo
path: ~/KlipperScreen
origin: https://github.com/KlipperScreen/KlipperScreen.git
managed_services: KlipperScreen
EOF
printf 'klipper\nmoonraker\nKlipperScreen\n' \
    > $HOME_DIR/printer_data/moonraker.asvc
chown -R pi:pi $HOME_DIR/printer_data

# KlipperSnapmakerJ1: modules, configuration, KlipperScreen add-on, theme
# and menu, calibration pictures and test prints
su pi -c "$J1/install.sh"

# Versions in the image
{
    echo "KlipperSnapmakerJ1-os build $(date -u +%Y-%m-%d)"
    cat /tmp/boot-versions
    echo "kernel $(cat /tmp/kernelrelease)"
    # As pi: git refuses repositories of another user
    for repo in klipper moonraker KlipperScreen KlipperSnapmakerJ1; do
        echo "$repo $(su pi -c "git -C $HOME_DIR/$repo describe --always \
            --tags")"
    done
    echo "mainsail $MAINSAIL_VERSION"
} > /etc/klipper-os-release

apt-get clean
rm -rf /var/lib/apt/lists/* /root/.cache $HOME_DIR/.cache
