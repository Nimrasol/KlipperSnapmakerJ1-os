# Design of KlipperSnapmakerJ1-os

The display module becomes a Klipper host like a Raspberry Pi: Debian with
Klipper, Moonraker, KlipperScreen and
[KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1).
Goals: as small as possible, a short boot (the printer is switched on and
off at its mains switch), and nothing changed that the EDL backup cannot
restore.

## Boot chain

```
PBL -> SBL1 -> TZ/RPM -> aboot (stock, locked, unchanged)
    -> boot partition: lk2nd (msm8909, snapmakerj1 target)
         panel and simple framebuffer, finds extlinux.conf on an ext2
         partition (the 256 MiB cache partition)
    -> cache partition: zImage, snapmakerj1.dtb, extlinux/extlinux.conf
    -> mainline Linux 6.12 (msm8916-mainline), root=PARTLABEL=userdata
    -> userdata partition: Debian bookworm armhf, systemd
```

lk2nd and the device tree of the display module come from
[eazrael](https://wiki.evilazrael.de/snapmaker-j1-klipper-installation)
(lk2nd branch `snapmakerj1`, device tree and kernel configuration from his
armbian-build fork).  `boot/inside.sh` builds both at pinned commits in a
Debian container; nothing of his Klipper setup is used.

The kernel command line (`boot/extlinux.conf`) keeps the console quiet,
rotates the text console to the landscape mounting and passes lk2nd's
framebuffer on (`lk2nd.pass-simplefb=autorefresh`): the display runs
through `simpledrm` on the framebuffer lk2nd set up, so no panel driver is
needed.

## Root file system

Built with `mmdebstrap` (`rootfs/build.sh`), packages in
`rootfs/packages.txt`, set up by `rootfs/setup.sh` in the armhf chroot.

| Part | Choice | Why |
| --- | --- | --- |
| Distribution | Debian bookworm armhf, minimal | the base of KIAUH and MainsailOS; no desktop |
| Init | systemd | Moonraker manages the services (`provider: systemd_cli`) |
| Display | `cage -r` (Wayland kiosk, pixman renderer), `seatd`, Xwayland | X cannot rotate on `simpledrm`; the touch screen is rotated the same way by a libinput calibration matrix (`udev/rules.d/90-j1-touch.rules`); the group `video` may switch the backlight (`udev/rules.d/90-j1-backlight.rules`), which KlipperSnapmakerJ1 turns off with the screen saver |
| Network | NetworkManager, `wcn36xx` | KlipperScreen's network panel uses NetworkManager |
| Time | systemd-timesyncd | the module has no battery backed clock |
| Access | SSH (user `pi`) | |
| Web interface | Mainsail behind `nginx-light` (port 80, Moonraker proxied as in MainsailOS) | works without internet; Moonraker updates it |
| Network name | `avahi-daemon` (`<hostname>.local`, IPv4 address only), `libnss-myhostname` | renamed in KlipperScreen (More → Network Name) through NetworkManager and avahi, without root rights; IPv4 only because Moonraker trusts the local IPv4 networks but not a client's public IPv6 address (slicer uploads were refused) |

The root file system is about 2.3 GB and grows to the userdata partition (4.9 GiB)
on the first boot.  Measured on the printer: about 0.8 s kernel and
7 s user space to `multi-user.target`.

### Services

| Unit | Purpose |
| --- | --- |
| `klipper`, `moonraker` | as user `pi`, like a KIAUH installation |
| `KlipperScreen` | switches to VT 7 (`j1-chvt`) and runs `cage -d -s -r -- j1-session` as `pi` |
| `seatd` | DRM and input access for cage |
| `wcnss-firmware` | loads the WLAN firmware once `/firmware` and `/persist` are mounted |
| `j1-firstboot` | grows the root file system once |
| `ssh` (drop-in) | creates the host keys of the device before the first start |
| `nginx`, `avahi-daemon` | Mainsail and the `.local` name |

Not started at boot: `NetworkManager-wait-online`, the apt, man-db and
e2scrub timers.  The journal is limited in size.

### Firmware of the module

`/etc/fstab` mounts the modem partition (`/firmware`, vfat) and the
persist partition (`/persist`, ext4) read only.  The kernel loads the
WCNSS firmware from `/firmware/image`; the WLAN calibration
(`WCNSS_qcom_wlan_nv.bin`) is linked from `/persist` by
`tmpfiles.d/wcnss-firmware.conf`.  `qcom_wcnss_pil` is held back
(`modprobe.d/wcnss-defer.conf`) until the mounts exist.

### Klipper stack

Installed for the user `pi` as KIAUH would: `~/klipper`, `~/moonraker`,
`~/KlipperScreen` at the versions of `KlipperSnapmakerJ1/versions.conf`
with their virtual environments (wheels from piwheels.org),
`~/printer_data`, and `~/KlipperSnapmakerJ1` installed by its
`install.sh` (including the calibration pictures from the stock
application of the printer).  Moonraker's update manager updates all of
them.

## What was not chosen

* **Stock Android kernel 3.10** (the first design of this project, its
  boot image signed with the AOSP test key the locked bootloader trusts):
  no source, the MDP3 framebuffer never showed the X output, the WLAN
  driver could not start without Android's services, and no systemd.
* **Armbian** (eazrael's image): works, but boots much longer and
  carries far more than a printer host needs.
* **X11** on `simpledrm`: the fbdev driver cannot set the mode and the
  modesetting driver showed nothing when rotated.
