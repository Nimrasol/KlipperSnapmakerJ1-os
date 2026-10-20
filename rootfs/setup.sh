#!/bin/bash
# Set up the root file system (runs inside the armhf chroot)
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Installs Klipper, Moonraker, KlipperScreen and KlipperSnapmakerJ1 for the
# user pi, the services and the boot scripts.
set -e
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
PIP_INDEX="--extra-index-url https://www.piwheels.org/simple"
HOME_DIR=/home/pi
J1=$HOME_DIR/KlipperSnapmakerJ1

# Locale and time zone
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen > /dev/null
echo 'LANG="en_US.UTF-8"' > /etc/default/locale
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# The stock kernel (ANDROID_PARANOID_NETWORK) only lets members of the
# Android groups inet and net_raw open network sockets
groupadd -g 3003 aid_inet
groupadd -g 3004 aid_net_raw
groupadd -g 3005 aid_net_admin
usermod -a -G aid_inet,aid_net_raw,aid_net_admin root
for user in _apt sshd messagebus; do
    id "$user" > /dev/null 2>&1 && usermod -a -G aid_inet "$user"
done
# Device groups that udev would otherwise create (used by mdev.conf)
for group in input netdev render; do
    getent group $group > /dev/null || groupadd -r $group
done

# User pi (password "klipper", change it after the first login)
useradd -m -s /bin/bash -G \
    sudo,dialout,tty,video,input,netdev,aid_inet,aid_net_raw pi
echo "pi:klipper" | chpasswd
echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi
chmod 0440 /etc/sudoers.d/010_pi

# Busybox mdev (the kernel has no devtmpfs)
ln -sf /bin/busybox /sbin/mdev

# Framebuffer refresher for the MDSS display
gcc -O2 -Wall -o /usr/local/sbin/fb-refresher /tmp/fb-refresher.c

# Boot scripts; the SSH host keys are created on the first boot
for script in j1-hardware j1-firstboot j1-network; do
    chmod 0755 /etc/init.d/$script
    update-rc.d $script defaults > /dev/null
done
update-rc.d ssh defaults > /dev/null
update-rc.d supervisor defaults > /dev/null
# udev comes with the X server (a dependency) but needs devtmpfs, which the
# stock kernel lacks; mdev creates the device nodes instead
update-rc.d udev disable > /dev/null 2>&1 || true
rm -f /etc/ssh/ssh_host_*

# supervisorctl for Moonraker (runs as pi)
sed -i 's/^chmod=0700.*/chmod=0770\nchown=root:pi/' \
    /etc/supervisor/supervisord.conf
mkdir -p /var/log/supervisor

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
grep -viE '^(PyGObject|pycairo|sdbus|python-mpv)' \
    KlipperScreen/scripts/KlipperScreen-requirements.txt \
    > /tmp/ks-requirements.txt
.KlipperScreen-env/bin/pip install -q $PIP_INDEX -r /tmp/ks-requirements.txt
rm /tmp/ks-requirements.txt

mkdir -p printer_data/config printer_data/logs printer_data/gcodes \
    printer_data/comms printer_data/database
"

# Moonraker: services through supervisord, no system package updates
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
provider: supervisord_cli
supervisord_config_path: /etc/supervisor/supervisord.conf
validate_service: False

[update_manager]
refresh_interval: 168
enable_system_updates: False

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
# and menu, calibration pictures and test prints from the stock display
# application of this printer
apk=
[ -e /tmp/base.apk ] && apk="--apk /tmp/base.apk"
su pi -c "$J1/install.sh $apk"
rm -f /tmp/base.apk

# Versions in the image
{
    echo "KlipperSnapmakerJ1-os build $(date -u +%Y-%m-%d)"
    # As pi: git refuses repositories of another user
    for repo in klipper moonraker KlipperScreen KlipperSnapmakerJ1; do
        echo "$repo $(su pi -c "git -C $HOME_DIR/$repo describe --always \
            --tags")"
    done
} > /etc/klipper-os-release

apt-get clean
rm -rf /var/lib/apt/lists/* /root/.cache $HOME_DIR/.cache
