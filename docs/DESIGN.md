# Design of KlipperSnapmakerJ1-os

The display module becomes a Klipper host like a Raspberry Pi: Debian with
Klipper, Moonraker, KlipperScreen and
[KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1).
The constraints come from [ANALYSIS.md](ANALYSIS.md): the stock kernel
3.10 (no source), a locked bootloader that trusts the AOSP test key, and
an Android partition layout.

## Boot chain

```
PBL -> SBL1 -> TZ/RPM -> LK (aboot, unchanged)
    -> boot partition: stock kernel + initramfs of this project
         (signed with the AOSP verity test key)
    -> initramfs /init: /dev (tmpfs + mdev), find "userdata" by name,
         mount it, switch_root
    -> userdata partition: Debian bookworm armhf, sysvinit
```

Everything before the boot partition is untouched; Android's system,
recovery and firmware partitions stay as they are.  The bootloader still
selects the panel and passes it to the kernel.

The initramfs offers a rescue shell over USB (RNDIS, telnet to
192.168.42.1) when the root file system is missing or cannot be mounted,
or when `/rescue` exists on it.

## Root file system

| Part | Choice | Why |
| --- | --- | --- |
| Distribution | Debian bookworm armhf | the base of KIAUH and MainsailOS; glibc 2.36 supports kernel 3.2+ |
| Init | sysvinit | systemd needs devtmpfs, fhandle and cgroups the kernel lacks |
| Devices | busybox `mdev` (also hotplug helper) | no devtmpfs, no udev |
| Services | supervisord | Moonraker can manage it (`provider: supervisord_cli`) for updates |
| Display | Xorg `fbdev` with `Rotate`, `evdev` touch, `fb-refresher` | no DRM, no udev; MDSS needs pans |
| Network | wpa_supplicant + dhcpcd on `wlan0` (prima), RNDIS over USB | stock driver and firmware |
| Access | SSH (user `pi`) | |

### Boot scripts (`/etc/init.d`)

* `j1-hardware` (rcS): mdev, `/firmware` and `/persist` read only,
  backlight, framebuffer unblank, `fb-refresher`, X configuration with the
  rotation of `/etc/klipper-os.conf` and the touch device found by name,
  USB network.
* `j1-firstboot` (rcS, once): grows the root file system to the
  partition, creates the SSH host keys of the device.
* `j1-network`: loads `pronto_wlan.ko`, starts wpa_supplicant and dhcpcd.
* `supervisor`: Klipper, Moonraker, KlipperScreen (`xinit` as `pi`).

### Klipper stack

Installed for the user `pi` as KIAUH would: `~/klipper` (at the version
the firmware patch of KlipperSnapmakerJ1 was made for), `~/moonraker`,
`~/KlipperScreen` with their virtual environments (wheels from
piwheels.org), `~/printer_data`, and `~/KlipperSnapmakerJ1` installed by
its `install.sh` (including the calibration pictures from the stock
application of the printer).  Moonraker's update manager updates all of
them; system packages are not updated by Moonraker.

## What was not chosen

* **Mainline kernel** (as postmarketOS for some MSM8909 devices): needs
  panel and touch drivers for this board and a new bootloader setup; a
  later option, the root file system would stay the same.
* **Linux in a chroot next to Android**: the Android `user` build has no
  root access, and Android would keep owning the display and the UART.
* **Unlocking the bootloader**: not needed, the AOSP test key signs the
  boot image.
