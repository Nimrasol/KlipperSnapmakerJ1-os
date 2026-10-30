# Development

Building the packages, how the USB stick installation works, and the
installation in Qualcomm EDL mode for development and as the fallback
when a printer no longer starts.  Users install from a USB stick, see
the [installation](INSTALL.md).

## Building

GitHub Actions builds the installation package
(`.github/workflows/build.yml`): **Actions → Build → Run workflow**, or a
tag `vX.Y.Z`, which attaches `KlipperSnapmakerJ1-install.zip` to the
release.  By hand, on Linux or WSL2 with Docker and `qemu-user-static`
(binfmt handler for ARM), and
[KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1)
checked out next to this repository:

```
./build.sh
install/build.sh out J1_V2.8.0_20251217.bin install-out
```

`install/build.sh` also needs `arm-linux-gnueabihf-gcc`, `apktool` and
Java.  The official Snapmaker update package it builds on is named in
`install/stock-package.conf`.  `build.sh` results in `out/`:

| File | Partition | Content |
| --- | --- | --- |
| `lk2nd.img` | `boot` | lk2nd, started by the stock bootloader |
| `linux-boot.img` | `cache` | ext2: kernel, device tree, maintenance system, `extlinux/extlinux.conf` |
| `userdata.img` | `userdata` | ext4: the Linux root file system, grown to the partition on the first boot |

The image contains nothing of the stock system: the WLAN firmware and
calibration are read on the printer from its own modem and persist
partitions.

The stock firmware package (`J1-Stock-Firmware.zip`, the way back) is
built by hand from a full eMMC dump of a display module with the
Snapmaker system and the official update package:

```
stock/build.sh sc20w-emmc-full.bin J1_V2.8.0_20251217.bin
```

`stock/clean.sh` removes the personal and device data of the dump (WLAN
networks, print files, Android ID, logs) and resets the setup flags of
the Snapmaker app, so its setup starts as on a new printer.

## How the USB stick installation works

### Stock firmware → Klipper

The stick holds `J1_V*.bin` and `install/` (`lk2nd.img`,
`linux-boot.img`, `rootfs.img.gz`, `manifest`).

1. The stock application installs the update package: the stock main
   controller firmware (unchanged) and, as its application update, a
   small trigger app.  Its screen **Klipper installation** installs the
   installer app (`install/installer-app`, signed with the platform key,
   system user).
2. The installer app hands a signed OTA package to the stock recovery
   (`RecoverySystem.installPackage`).  Its `update-binary` checks the
   images on the stick against the sha256 compiled into it, writes lk2nd
   to `boot` and `linux-boot.img` to `cache`, clears the boot command in
   `misc` and restarts.  The recovery shows nothing on the J1: the
   screen stays dark for up to a minute.
3. lk2nd starts the maintenance system (`maint/`, extlinux label
   `maint`), which checks `rootfs.img.gz` and writes it to `userdata`,
   then starts Linux.
4. The first start installs the Klipper firmware on the main controller
   (`j1-mcu-firmware.service`, `snapmaker_j1_flash.py`, at most three
   tries, log in `/var/log/j1-mcu-firmware.log`), then Klipper starts.

Until the restart in step 2 nothing of the Snapmaker system is changed;
the screen **Klipper installation** offers **Back to Snapmaker**.

### Klipper → stock firmware

The stick holds `J1_V*.bin` and `stock-restore/` (`boot.img`,
`userdata.img.gz`, `userdata-footer.bin`, `cache.img.gz`, `manifest`).

1. KlipperScreen, **More → System → Stock Firmware** (end of the page),
   runs `scripts/snapmaker_j1_stock.py` of KlipperSnapmakerJ1: it checks
   the package and `stock-restore/`, installs the stock main controller
   firmware from the package through the factory bootloader and restarts
   into the maintenance system.
2. The maintenance system checks the files against the manifest and
   writes `userdata`, its encryption footer, `cache` and `boot`.
3. The printer starts the Snapmaker system.

## Installation in EDL mode

### What you need

* A Linux computer with USB for EDL and for the main controller, for
  example a Raspberry Pi, with Python 3,
  [bkerler/edl](https://github.com/bkerler/edl) and pyserial.
* A full eMMC backup of your display module (`sc20w-emmc-full.bin`), read
  in EDL mode with `edl rf sc20w-emmc-full.bin`: the way back to the
  stock system in EDL mode.

### EDL mode

Switch the printer off, set the switch on the back of the display module
to EDL and switch the printer on.  The USB port on the front of the
printer is then a USB device of the display module (`lsusb`:
`05c6:9008 Qualcomm ... QDL mode`); connect it to the Linux computer.
In normal operation the same port is a USB host.  Set the switch back
before the next start.

### Flash the display module

```
edl w boot out/lk2nd.img
edl w cache out/linux-boot.img
edl w userdata out/userdata.img
edl reset
```

This replaces the Android data and cache partitions (the Snapmaker
application and its data); the boot chain, system and recovery stay
unchanged.  Set the EDL switch back before the next power up.  The first
start installs the Klipper firmware on the main controller, grows the
file system to the partition and creates the SSH host keys.

### Main controller firmware by hand

The first start of the image does this by itself.  By hand, build the
firmware from the Klipper version the image contains (the one in
`KlipperSnapmakerJ1/versions.conf`, needs `gcc-arm-none-eabi`):

```
git clone https://github.com/Klipper3d/klipper.git ~/klipper
git -C ~/klipper checkout \
    $(awk '$1 == "klipper" {print $2}' KlipperSnapmakerJ1/versions.conf)
KLIPPER_DIR=~/klipper KlipperSnapmakerJ1/firmware/build.sh
```

and install `firmware/out/mc.bin` through the USB port of the main
controller (USART1 through a CH340):

```
python3 KlipperSnapmakerJ1/scripts/snapmaker_j1_flash.py -d /dev/ttyUSB0 -v \
    KlipperSnapmakerJ1/firmware/out/mc.bin
```

The script restarts the stock firmware (`M1999`) and installs the image
through the factory bootloader, which keeps its own pages (about 30 s).
If the firmware does not answer, run it with `-w 60` and switch the
printer off and on: the bootloader listens for 6 s after every power up.

### Back to the stock system in EDL mode

1. Main controller: install a stock `mc.bin` with
   `scripts/snapmaker_j1_flash.py` of KlipperSnapmakerJ1 (the cached
   package of the stock display is in the backup at
   `/data/data/com.snapmaker.j1/app_update/mc.bin`).
2. Display module, in EDL mode, from your backup:
   ```
   for p in boot cache userdata; do
       tools/extract_partition.py sc20w-emmc-full.bin $p $p-stock.img
       edl w $p $p-stock.img
   done
   edl reset
   ```

## Access and updates

SSH: `ssh pi@snapmaker-j1.local`, password `klipper` (change it with
`passwd`).  Without a display, a NetworkManager connection file can be
added to the image before flashing
(`/etc/NetworkManager/system-connections/`, mode 600, written with
`debugfs -w` into `userdata.img`).

Moonraker's update manager updates Klipper, Moonraker, KlipperScreen,
KlipperSnapmakerJ1 and Mainsail.  The image installs the versions of
`KlipperSnapmakerJ1/versions.conf`.  When a Klipper update changes the
protocol to the main controller, Klipper reports it; rebuild the firmware
with `~/KlipperSnapmakerJ1/firmware/build.sh` and install it.  Debian
packages are updated with `sudo apt upgrade`; the kernel and lk2nd only
by a new image.
