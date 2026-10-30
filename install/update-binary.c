/*
 * OTA update-binary for the Snapmaker J1 recovery: install KlipperSnapmakerJ1-os
 *
 * Copyright (C) 2026  Nimrasol
 *
 * This file may be distributed under the terms of the GNU GPLv3 license.
 *
 * The stock recovery (standard AOSP) verifies the enclosing OTA package
 * against its trusted key (the public AOSP test key) and then runs this
 * program as root.  It writes the two small boot parts of
 * KlipperSnapmakerJ1-os and reboots; the large root file system is written
 * afterwards by the maintenance system from the same USB stick.
 *
 *   boot  <- lk2nd.img        (the boot loader)
 *   cache <- linux-boot.img   (ext2 with extlinux, kernel, maint; built in
 *                              "install" mode: default=maint, request=install)
 *
 * The images are read from a FAT USB stick in the directory
 * install/ (marker install/lk2nd.img).  They are NOT inside the OTA
 * package, so the package stays small; this program checks their sha256
 * against the digests the package was built with (passed as argv below is
 * not used for that - the digests are compiled in by build-ota.sh).
 *
 * Recovery still holds /cache mounted while this runs, so we must not
 * return into its finish logic after overwriting cache.  Instead we clear
 * the bootloader control block in misc (so the next boot is normal, not
 * recovery) and reboot by ourselves.
 *
 * recovery calls:  update-binary <api> <pipefd> <zipfile>
 */
#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

#include "digests.h"   /* generated: SHA256 of lk2nd.img and linux-boot.img */
#include "sha256.h"

#define USB_DIR   "/tmp/kusb"
#define SRC_DIR   "install"
#define BLOCK_DIR "/dev/block"

static int g_pipe = -1;

static void ui(const char *fmt, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s\n", buf);
    if (g_pipe >= 0) {
        char line[560];
        int n = snprintf(line, sizeof(line), "ui_print %s\nui_print \n", buf);
        if (write(g_pipe, line, n) < 0)
            ; /* progress only; a closed pipe must not stop the install */
    }
}

static int clear_bcb(void);

/* Reboot into the normal system.  The Qualcomm kernel only records a
   restart reason for a reboot with an argument; without one an earlier
   reason ("recovery", from Android) may stay and the boot loader starts the
   recovery again.  An argument it does not know is recorded as normal. */
static void reboot_normal(void)
{
    sync();
    syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
            LINUX_REBOOT_CMD_RESTART2, "normal");
    syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
            LINUX_REBOOT_CMD_RESTART, NULL);
}

static void die(const char *msg)
{
    ui("ERROR: %s", msg);
    ui("Nothing was changed.  The printer restarts with the Snapmaker system.");
    /* No boot part was written yet when die() is used: leave the recovery
       for good (the recovery request would repeat this endlessly) */
    if (clear_bcb() != 0)
        ui("could not clear the recovery request");
    sleep(5);
    reboot_normal();
    _exit(1);
}

/* Resolve a partition by name to its /dev/block node via the by-name links,
   falling back to the PARTNAME in sysfs. */
static int part_path(const char *name, char *out, size_t outlen)
{
    char link[256];
    snprintf(link, sizeof(link), "%s/bootdevice/by-name/%s", BLOCK_DIR, name);
    if (access(link, F_OK) == 0) {
        snprintf(out, outlen, "%s", link);
        return 0;
    }
    snprintf(link, sizeof(link), "%s/platform/soc.0/7824900.sdhci/by-name/%s",
             BLOCK_DIR, name);
    if (access(link, F_OK) == 0) {
        snprintf(out, outlen, "%s", link);
        return 0;
    }
    /* sysfs: find mmcblk0pN whose uevent PARTNAME matches */
    DIR *d = opendir("/sys/class/block");
    struct dirent *e;
    while (d && (e = readdir(d))) {
        if (strncmp(e->d_name, "mmcblk", 6) != 0)
            continue;
        char uev[300], line[256];
        snprintf(uev, sizeof(uev), "/sys/class/block/%s/uevent", e->d_name);
        FILE *f = fopen(uev, "r");
        if (!f)
            continue;
        int match = 0;
        while (fgets(line, sizeof(line), f)) {
            char *p = strstr(line, "PARTNAME=");
            if (p) {
                p += 9;
                p[strcspn(p, "\r\n")] = 0;
                match = strcmp(p, name) == 0;
            }
        }
        fclose(f);
        if (match) {
            closedir(d);
            snprintf(out, outlen, "%s/%s", BLOCK_DIR, e->d_name);
            return 0;
        }
    }
    if (d)
        closedir(d);
    return -1;
}

/* Copy src file onto the dest block device, verifying the sha256. */
static int write_image(const char *src, const char *partname,
                       const unsigned char *want)
{
    char dev[256];
    if (part_path(partname, dev, sizeof(dev)) != 0) {
        ui("partition %s not found", partname);
        return -1;
    }
    int in = open(src, O_RDONLY);
    if (in < 0) {
        ui("cannot open %s", src);
        return -1;
    }
    int out = open(dev, O_WRONLY);
    if (out < 0) {
        ui("cannot open %s", dev);
        close(in);
        return -1;
    }
    SHA256_CTX ctx;
    sha256_init(&ctx);
    static unsigned char buf[1 << 20];
    ssize_t n;
    long long total = 0;
    while ((n = read(in, buf, sizeof(buf))) > 0) {
        if (write(out, buf, n) != n) {
            ui("write to %s failed", partname);
            close(in);
            close(out);
            return -1;
        }
        sha256_update(&ctx, buf, n);
        total += n;
    }
    fsync(out);
    close(in);
    close(out);
    unsigned char got[32];
    sha256_final(&ctx, got);
    if (memcmp(got, want, 32) != 0) {
        ui("%s on the stick is damaged (checksum)", src);
        return -1;
    }
    ui("%s written (%lld bytes)", partname, total);
    return 0;
}

/* Clear the bootloader control block (command, status, recovery arguments,
   stage: the first 2 KB of misc) so the next boot is normal; read back to
   make sure. */
static int clear_bcb(void)
{
    char dev[256];
    if (part_path("misc", dev, sizeof(dev)) != 0)
        return -1;
    int fd = open(dev, O_RDWR | O_SYNC);
    if (fd < 0)
        return -1;
    static unsigned char zero[2048], back[2048];
    int ok = pwrite(fd, zero, sizeof(zero), 0) == (ssize_t)sizeof(zero);
    fsync(fd);
    ok = ok && pread(fd, back, sizeof(back), 0) == (ssize_t)sizeof(back)
            && memcmp(back, zero, sizeof(zero)) == 0;
    close(fd);
    return ok ? 0 : -1;
}

/* Try to mount any FAT USB partition that carries SRC_DIR/lk2nd.img. */
static int mount_stick(char *dir, size_t dirlen)
{
    mkdir(USB_DIR, 0755);
    for (int tries = 0; tries < 60; tries++) {
        DIR *d = opendir("/sys/class/block");
        struct dirent *e;
        while (d && (e = readdir(d))) {
            if (e->d_name[0] != 's' || e->d_name[1] != 'd')
                continue;                 /* sd* only (USB mass storage) */
            if (!e->d_name[2])
                continue;                 /* skip whole disk sda, want sda1 */
            char dev[300];
            snprintf(dev, sizeof(dev), "%s/%s", BLOCK_DIR, e->d_name);
            umount(USB_DIR);
            if (mount(dev, USB_DIR, "vfat", MS_RDONLY, NULL) != 0)
                continue;
            char marker[320];
            snprintf(marker, sizeof(marker), "%s/%s/lk2nd.img", USB_DIR, SRC_DIR);
            if (access(marker, F_OK) == 0) {
                closedir(d);
                snprintf(dir, dirlen, "%s/%s", USB_DIR, SRC_DIR);
                return 0;
            }
            umount(USB_DIR);
        }
        if (d)
            closedir(d);
        sleep(1);
    }
    return -1;
}

int main(int argc, char **argv)
{
    if (argc >= 3)
        g_pipe = atoi(argv[2]);

    ui(" ");
    ui("Installing Klipper (KlipperSnapmakerJ1-os)");
    ui("Do not switch the printer off.  It restarts by itself.");

    char dir[400];
    if (mount_stick(dir, sizeof(dir)) != 0)
        die("no USB stick with the Klipper install files found");

    char lk[512], lb[512];
    snprintf(lk, sizeof(lk), "%s/lk2nd.img", dir);
    snprintf(lb, sizeof(lb), "%s/linux-boot.img", dir);

    /* From here on boot parts get overwritten: no return to the stock
       system is possible, so failures continue trying rather than aborting
       to a half-written state. */
    ui("Writing the boot loader...");
    if (write_image(lk, "boot", SHA256_LK2ND) != 0)
        die("boot loader not written");

    ui("Writing the Linux boot partition...");
    umount("/cache");                 /* drop the recovery handle on cache */
    if (write_image(lb, "cache", SHA256_LINUX_BOOT) != 0) {
        ui("FATAL: cache half written, retrying once...");
        if (write_image(lb, "cache", SHA256_LINUX_BOOT) != 0)
            die("Linux boot partition not written");
    }

    /* The recovery package was on the old cache: a recovery started again
       would find nothing and wait for a key, so the request must be gone */
    for (int i = 0; clear_bcb() != 0; i++) {
        ui("could not clear the recovery request, retrying...");
        if (i >= 10)
            break;
        sleep(1);
    }
    ui("Done.  Restarting into the Klipper installer...");
    sleep(3);
    reboot_normal();
    return 0;
}
