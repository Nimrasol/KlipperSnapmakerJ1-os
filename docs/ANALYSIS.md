# Analysis of the J1 display module

The findings this image is built on, from a full eMMC dump of the display
module of a Snapmaker J1 (read in Qualcomm EDL mode with
[bkerler/edl](https://github.com/bkerler/edl), read only).

## Module

| Item | Value |
| --- | --- |
| Module | Quectel SC20-W, Qualcomm MSM8909 (4x Cortex-A7, 32 bit) |
| eMMC | 7.8 GB (15269888 sectors of 512 bytes), GPT |
| Android | 7.1.2 (N2G47H), `user` build signed with test-keys, ADB enabled by default (`persist.sys.usb.config=diag,serial_smd,rmnet_qti_bam,adb`) |
| Kernel | Linux 3.10.49, built 2022-10-10, zImage with 50 appended device trees (MSM8909 reference boards) |
| Display | MIPI DSI video mode panel, 720x1280 portrait, mounted in landscape; the bootloader selects one of ili9881c, ili9881d or hx8394f (720p) |
| Touch | Goodix GT9xx (`goodix,gt9xx`, input device "Goodix-CTP") |
| Main controller link | BLSP1 UART2: `/dev/ttyHSL1`, 115200 baud in the stock system |

## Partitions

| Partition | Index | Size | Use in this image |
| --- | --- | --- | --- |
| modem | 1 | 64 MiB | read only, mounted as `/firmware` (WCNSS WLAN firmware) |
| sbl1, aboot, rpm, tz | | | unchanged (boot chain) |
| boot | 20 | 32 MiB | **replaced**: stock kernel with the initramfs of this project |
| system | 21 | 1.5 GiB | unchanged (Android) |
| persist | 22 | 32 MiB | read only, mounted as `/persist` (WLAN calibration) |
| recovery | 24 | 32 MiB | unchanged |
| userdata | 33 | 4.9 GiB | **replaced**: Linux root file system |

## Verified boot

The device is locked (`devinfo`: unlocked 0, tampered 0).  The bootloader
(LK, `aboot`) verifies the boot image against its embedded key store.  The
stock boot image carries an AOSP `AndroidVerifiedBootSignature` with the
certificate `CN=Android, O=Android, emailAddress=android@android.com`,
serial `970F983909AA8949` (SHA1 fingerprint
`14:A3:3C:EB:E3:E8:66:7B:40:9E:F8:14:2A:9D:56:25:9E:C8:32:8E`), and the
modulus of this key is embedded in `aboot`.  This is the public AOSP test
key `verity` (`build/target/product/security/verity.{pk8,x509.pem}`).

`tools/boot_signer.py` re-signs the stock boot image with this key into a
result that is byte identical to the stock boot partition (image and
signature), so boot images of this project are accepted by the locked
bootloader.  No unlocking is needed and the boot chain stays unchanged.

## Kernel

No kernel source is available, so the image uses the stock kernel from the
user's own dump.  Its configuration (`/proc/config.gz`, also embedded in
the zImage) decides what the Linux system can be:

| Option | State | Consequence |
| --- | --- | --- |
| `DEVTMPFS` | not set | `/dev` is a tmpfs filled by busybox `mdev` (initramfs and boot) |
| `FHANDLE`, `AUTOFS4_FS`, `CGROUP` controllers | missing | systemd and udev cannot run: sysvinit, mdev, supervisord |
| `ANDROID_PARANOID_NETWORK` | set | only members of group 3003 (`aid_inet`) open sockets; users are added to it |
| `SECURITY_SELINUX` | set | no policy is loaded, so it does not restrict |
| `FB_MSM_MDSS` | set | display through `/dev/fb0`; new content needs `FBIOPAN_DISPLAY` (`fb-refresher`) |
| `TOUCHSCREEN_GT9XX`, `INPUT_EVDEV` | set | touch through `/dev/input/event*` |
| `SERIAL_MSM_HSL` | set | `/dev/ttyHSL0`, `/dev/ttyHSL1` |
| `WCNSS_CORE_PRONTO`, `CFG80211`, `MODULES` | set | WLAN with the stock `pronto_wlan.ko` (prima) |
| `USB_G_ANDROID` | set | USB network (RNDIS) for setup and rescue |
| `MSM_DLOAD_MODE` | set | `reboot edl` enters the download mode |
| firmware search path | | `/lib/firmware`, `/firmware/image` |

### UART baud rates

The UART driver (`msm_hsl_set_baud_rate`, disassembled from the stock
kernel) supports 300-57600, 115200, 230400, 460800, 921600, 1000000,
1152000, 1500000, 2500000, 3000000, 3200000, 3500000, 3686400 and 4000000
baud.  Any other rate (eg Klipper's usual 250000) silently keeps the
previous setting, so the main controller firmware of KlipperSnapmakerJ1
uses 230400 baud.

## Stock parts used

Taken from the dump of the user's printer by `tools/extract_stock.py`, not
distributed with this project:

* `boot.img`: the kernel (zImage with device trees) and its header
* `modem.img`: mounted read only; WCNSS firmware in `/firmware/image`
* `persist.img`: WLAN calibration (`WCNSS_qcom_wlan_nv.bin`)
* `/system/lib/modules/pronto/pronto_wlan.ko`, `WCNSS_cfg.dat`,
  `WCNSS_qcom_cfg.ini`: WLAN driver and configuration
* `/data/app/com.snapmaker.j1-*/base.apk`: pictures and test prints of the
  calibration menu of KlipperSnapmakerJ1
