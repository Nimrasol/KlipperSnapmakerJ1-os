# Installation

> **Experimental.**  Tested on one J1 (board revision 2).  Keep the full
> backup of your display module: it is the way back to the stock system.

## What you need

* A Linux computer with USB for EDL and for the main controller, for
  example a Raspberry Pi, with Python 3,
  [bkerler/edl](https://github.com/bkerler/edl) and pyserial.
* A full eMMC backup of your display module (`sc20w-emmc-full.bin`), read
  in Qualcomm EDL mode (below) with `edl rf sc20w-emmc-full.bin`.  The
  build takes the WLAN driver and configuration from it, and it is the
  way back to the stock system.
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
./build.sh /path/to/sc20w-emmc-full.bin
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

Choose the network in KlipperScreen under **More → Network** and enter
its password.  The printer's address is shown there; then

```
ssh pi@<address>          # password: klipper - change it with passwd
```

The printer announces itself as **snapmaker-j1.local**.  With several
printers, give each its own name in KlipperScreen under **More → Network
Name** (letters, digits and `-`); the new name is used at once.

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
