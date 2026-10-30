# Installation

> **Experimental.**  Tested on one J1 (board revision 2).  Keep the full
> backup of your display module: it is the way back to the stock system.

There are two ways to install:

* **From a USB stick** on the stock touch screen, without EDL: the way
  for users, see [USB stick](#usb-stick) below and the
  [installation of KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1#installation).
* **In EDL mode** with a Linux computer: for development and as the
  fallback when a printer no longer starts (sections 1 to 5).

## USB stick

### Stock firmware → Klipper

`install/build.sh` builds the stick from the images of `build.sh` and an
official Snapmaker update package: `J1_V*.bin` and the folder `install/`
(`lk2nd.img`, `linux-boot.img`, `rootfs.img.gz`, `manifest`).

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

`stock/build.sh` builds the stock firmware package from a full eMMC
dump of a display module with the Snapmaker system and the official
update package: `J1_V*.bin` and `stock-restore/` (`boot.img`,
`userdata.img.gz`, `userdata-footer.bin`, `cache.img.gz`, `manifest`).
`stock/clean.sh` removes the personal and device data of the dump (WLAN
networks, print files, Android ID, logs) and resets the setup flags of
the Snapmaker app, so its setup starts as on a new printer.

1. KlipperScreen, **More → System → Stock Firmware** (end of the page),
   runs `scripts/snapmaker_j1_stock.py` of KlipperSnapmakerJ1: it checks
   the package and `stock-restore/`, installs the stock main controller
   firmware from the package through the factory bootloader and restarts
   into the maintenance system.
2. The maintenance system checks the files against the manifest and
   writes `userdata`, its encryption footer, `cache` and `boot`.
3. The printer starts the Snapmaker system.

## What you need

* A Linux computer with USB for EDL and for the main controller, for
  example a Raspberry Pi, with Python 3,
  [bkerler/edl](https://github.com/bkerler/edl) and pyserial.
* A full eMMC backup of your display module (`sc20w-emmc-full.bin`), read
  in Qualcomm EDL mode (below) with `edl rf sc20w-emmc-full.bin`.  It is
  the way back to the stock system in EDL mode; the build does not need
  it.
* For building: a Linux PC (or WSL2) with Docker and `qemu-user-static`
  (binfmt handler for ARM), and
  [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1)
  checked out next to this repository.

### EDL mode

Switch the printer off, set the switch on the back of the display module
to EDL and switch the printer on.  The USB port on the front of the
printer is then a USB device of the display module (`lsusb`:
`05c6:9008 Qualcomm ... QDL mode`); connect it to the Linux computer.
In normal operation the same port is a USB host.  Set the switch back
before the next start.

## 1. Main controller firmware

Build the firmware from the Klipper version the image contains (the one
in `KlipperSnapmakerJ1/versions.conf`):

```
git clone https://github.com/Klipper3d/klipper.git ~/klipper
git -C ~/klipper checkout \
    $(awk '$1 == "klipper" {print $2}' KlipperSnapmakerJ1/versions.conf)
KLIPPER_DIR=~/klipper KlipperSnapmakerJ1/firmware/build.sh
```

(needs `gcc-arm-none-eabi`) and install `firmware/out/mc.bin` through the
USB port of the main controller (USART1 through a CH340):

```
python3 KlipperSnapmakerJ1/scripts/snapmaker_j1_flash.py -d /dev/ttyUSB0 -v \
    KlipperSnapmakerJ1/firmware/out/mc.bin
```

The script restarts the stock firmware (`M1999`) and installs the image
through the factory bootloader, which keeps its own pages (about 30 s).
If the firmware does not answer, run it with `-w 60` and switch the
printer off and on: the bootloader listens for 6 s after every power up.
Afterwards the stock display can no longer control the printer.

## 2. Build the image

```
./build.sh
```

Results in `out/`:

| File | Partition | Content |
| --- | --- | --- |
| `lk2nd.img` | `boot` | lk2nd, started by the stock bootloader |
| `linux-boot.img` | `cache` | ext2: kernel, device tree, `extlinux/extlinux.conf` |
| `userdata.img` | `userdata` | ext4: the Linux root file system, grown to the partition on the first boot |

The first build takes about an hour (kernel, Python packages under
emulation).

## 3. Flash the display module

In EDL mode:

```
edl w boot out/lk2nd.img
edl w cache out/linux-boot.img
edl w userdata out/userdata.img
edl reset
```

This replaces the Android data and cache partitions (the Snapmaker
application and its data); the boot chain, system and recovery stay
unchanged.  Set the EDL switch back before the next power up.

## 4. First boot

The Snapmaker logo of the bootloader, a short lk2nd screen, then the
kernel; KlipperScreen appears about 15 s after power up.  The first boot
grows the file system to the partition and creates the SSH host keys of
the device.

## 5. WLAN and access

Choose the network in KlipperScreen under **More → Network → WLAN** and
enter its password.  The printer's address is shown there; then

```
ssh pi@<address>          # password: klipper - change it with passwd
```

The printer announces itself as **snapmaker-j1.local**.  With several
printers, give each its own name in KlipperScreen under **More → Network
→ Network Name** (letters, digits and `-`); the new name is used at once.

* **Mainsail** runs on the printer: open **http://snapmaker-j1.local**
  (or the printer's address).  The update manager keeps it up to date.
* **Slicers** (OrcaSlicer, PrusaSlicer, SuperSlicer, Cura with the
  OctoPrint plugin): add the printer as a Moonraker or OctoPrint host
  with `snapmaker-j1.local` (port 80, or 7125 for Moonraker directly) to
  upload and start prints.
* **Fluidd** is not installed.  Its hosted page (app.fluidd.xyz) is only
  served over https, and browsers do not let an https page connect to
  the printer's unencrypted Moonraker.

Without a display, a NetworkManager connection file can be added to the
image before flashing (`/etc/NetworkManager/system-connections/`, mode
600, written with `debugfs -w` into `userdata.img`).

## Updates

Moonraker's update manager updates Klipper, Moonraker, KlipperScreen and
KlipperSnapmakerJ1 from their GitHub repositories (KlipperSnapmakerJ1 only
while its repository is public; otherwise Moonraker cannot fetch it).
The image installs the versions of `KlipperSnapmakerJ1/versions.conf`.
When a Klipper update changes the protocol to the main controller,
Klipper reports it; rebuild the firmware with
`~/KlipperSnapmakerJ1/firmware/build.sh` and install it.  Debian packages
are updated with `sudo apt upgrade`; the kernel and lk2nd only by a new
image.

## Back to the stock system

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
