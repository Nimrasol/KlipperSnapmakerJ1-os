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
 * The images are read from a FAT USB stick in the directory install/
 * (marker install/lk2nd.img).  lk2nd.img is checked against the sha256
 * compiled in by build-ota.sh, linux-boot.img against install/manifest
 * (linux-boot.img carries a copy of this package, see below, so its digest
 * cannot be compiled in here).
 *
 * Both images are read into memory and checked first; the stick is then
 * unmounted and the eMMC written in small steps.  The stick is not read
 * while the eMMC is written, which keeps the load on the supply of the
 * display module low (fast USB 3 sticks draw a lot).
 *
 * Recovery still holds /cache mounted while this runs, so we must not
 * return into its finish logic after overwriting cache.  Instead we clear
 * the bootloader control block in misc (so the next boot is normal, not
 * recovery) and reboot by ourselves.  If the recovery starts again anyway,
 * it finds the copy of this package in the new cache
 * (/cache/recovery/klipper-ota.zip, put there by install/build.sh) and runs
 * it once more, which completes the installation.
 *
 * Every run appends to install/install-log.txt on the stick (with the
 * kernel's boot reason, and the last kernel log and the recovery log of a
 * run that did not end), so a failed installation can be analysed without
 * a dump of the eMMC.
 *
 * recovery calls:  update-binary <api> <pipefd> <zipfile>
 */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/klog.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <linux/fs.h>
#include <linux/reboot.h>

#include "digests.h"   /* generated: SHA256 of lk2nd.img, INSTALLER_VERSION */
#include "sha256.h"

#define USB_DIR   "/tmp/kusb"
#define SRC_DIR   "install"
#define BLOCK_DIR "/dev/block"
#define LOG_FILE  "install-log.txt"

/* eMMC writes: 1 MiB steps, each flushed, with a short pause */
#define WRITE_STEP   (1 << 20)
#define WRITE_PAUSE  20000          /* us */

static int g_pipe = -1;
static char g_stick_dev[300];       /* mounted stick partition */
static int g_stick_mounted;
static int g_stick_rw;

/* -- log --------------------------------------------------------------- */

/* Lines are collected here and appended to the log on the stick whenever
   it is mounted (it is not while the eMMC is written). */
static char g_log[256 * 1024];
static size_t g_loglen;

static double uptime(void)
{
    double up = 0;
    FILE *f = fopen("/proc/uptime", "r");
    if (f) {
        if (fscanf(f, "%lf", &up) != 1)
            up = 0;
        fclose(f);
    }
    return up;
}

static void log_raw(const char *s, size_t n)
{
    if (n > sizeof(g_log) - g_loglen)
        n = sizeof(g_log) - g_loglen;
    memcpy(g_log + g_loglen, s, n);
    g_loglen += n;
}

static void logf_(const char *fmt, ...)
{
    char buf[600];
    int n = snprintf(buf, sizeof(buf), "%8.2f ", uptime());
    va_list ap;
    va_start(ap, fmt);
    n += vsnprintf(buf + n, sizeof(buf) - n - 1, fmt, ap);
    va_end(ap);
    if (n > (int)sizeof(buf) - 2)
        n = sizeof(buf) - 2;
    buf[n++] = '\n';
    log_raw(buf, n);
}

/* Write data to a file on the stick (append or replace), flushed */
static int stick_write(const char *name, const char *data, size_t len,
                       int append)
{
    if (!g_stick_mounted || !g_stick_rw)
        return -1;
    char path[400];
    snprintf(path, sizeof(path), "%s/%s/%s", USB_DIR, SRC_DIR, name);
    int fd = open(path, O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC),
                  0644);
    if (fd < 0)
        return -1;
    int ok = write(fd, data, len) == (ssize_t)len;
    ok = fsync(fd) == 0 && ok;
    close(fd);
    return ok ? 0 : -1;
}

static void log_flush(void)
{
    if (g_loglen && stick_write(LOG_FILE, g_log, g_loglen, 1) == 0)
        g_loglen = 0;
}

static void ui(const char *fmt, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s\n", buf);
    logf_("%s", buf);
    if (g_pipe >= 0) {
        char line[560];
        int n = snprintf(line, sizeof(line), "ui_print %s\nui_print \n", buf);
        if (write(g_pipe, line, n) < 0)
            ; /* progress only; a closed pipe must not stop the install */
    }
}

/* Copy (the end of) a file into a file on the stick */
static void stick_copy(const char *src, const char *name, size_t max)
{
    static char buf[256 * 1024];
    if (max > sizeof(buf))
        max = sizeof(buf);
    int fd = open(src, O_RDONLY);
    if (fd < 0) {
        logf_("%s: %s", src, strerror(errno));
        return;
    }
    /* /proc files have no size: read all, keep the last max bytes */
    size_t len = 0;
    for (;;) {
        if (len == max) {
            memmove(buf, buf + max / 2, max - max / 2);
            len = max - max / 2;
        }
        ssize_t n = read(fd, buf + len, max - len);
        if (n <= 0)
            break;
        len += n;
    }
    close(fd);
    if (stick_write(name, buf, len, 0) == 0)
        logf_("%s saved as %s (%zu bytes)", src, name, len);
}

/* Kernel lines about the reason of this start, and the command line */
static void log_boot_reason(void)
{
    static char kbuf[512 * 1024];
    int n = klogctl(3 /* SYSLOG_ACTION_READ_ALL */, kbuf, sizeof(kbuf) - 1);
    if (n > 0) {
        kbuf[n] = 0;
        for (char *l = kbuf; l && *l;) {
            char *e = strchr(l, '\n');
            if (e)
                *e = 0;
            if (strstr(l, "reason") || strstr(l, "warm_reset") ||
                strstr(l, "Kernel command line"))
                logf_("kmsg: %.400s", l);
            l = e ? e + 1 : NULL;
        }
    }
    char cmd[1024] = "";
    FILE *f = fopen("/proc/cmdline", "r");
    if (f) {
        if (!fgets(cmd, sizeof(cmd), f))
            cmd[0] = 0;
        fclose(f);
    }
    cmd[strcspn(cmd, "\n")] = 0;
    logf_("cmdline: %s", cmd);
}

/* Number of earlier runs on this stick that started but did not reach
   their end (a run that ended logs "=== end") */
static int unfinished_runs(void)
{
    char path[400];
    snprintf(path, sizeof(path), "%s/%s/%s", USB_DIR, SRC_DIR, LOG_FILE);
    FILE *f = fopen(path, "r");
    if (!f)
        return 0;
    char line[700];
    int open_runs = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "=== begin"))
            open_runs++;
        else if (strstr(line, "=== end"))
            open_runs = 0;
    }
    fclose(f);
    return open_runs;
}

/* -- partitions, misc, reboot ------------------------------------------ */

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
    int e1 = errno;
    syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
            LINUX_REBOOT_CMD_RESTART, NULL);
    logf_("reboot failed: %s / %s", strerror(e1), strerror(errno));
}

static void stick_umount(void)
{
    if (!g_stick_mounted)
        return;
    log_flush();
    sync();
    if (umount(USB_DIR) == 0)
        g_stick_mounted = 0;
    else
        logf_("umount stick: %s", strerror(errno));
}

static int stick_mount(void)
{
    if (g_stick_mounted)
        return 0;
    g_stick_rw = mount(g_stick_dev, USB_DIR, "vfat", MS_NOATIME, NULL) == 0;
    if (!g_stick_rw &&
        mount(g_stick_dev, USB_DIR, "vfat", MS_RDONLY, NULL) != 0)
        return -1;
    g_stick_mounted = 1;
    return 0;
}

/* Log, put the log on the stick and restart */
static void finish(const char *how)
{
    logf_("=== end (%s)", how);
    stick_mount();
    stick_umount();
    sleep(2);
    reboot_normal();
    /* still here: keep the reason on the stick */
    stick_mount();
    stick_umount();
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
    finish("error");
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

/* Clear the bootloader control block (command, status, recovery arguments,
   stage: 2 KB) so the next boot is normal; read back to make sure.  The
   boot loader reads it at the start of misc; the J1 recovery keeps its own
   copy 512 KB into misc ("boot-recovery --update_package=..."), which
   would make a recovery started again look for the package.  Both are
   cleared. */
static const off_t bcb_offsets[] = { 0, 512 * 1024 };

static int clear_bcb(void)
{
    char dev[256];
    if (part_path("misc", dev, sizeof(dev)) != 0) {
        logf_("misc not found");
        return -1;
    }
    int fd = open(dev, O_RDWR | O_SYNC);
    if (fd < 0) {
        logf_("open misc: %s", strerror(errno));
        return -1;
    }
    static unsigned char zero[2048], back[2048];
    int ok = 1;
    for (size_t i = 0; i < sizeof(bcb_offsets) / sizeof(bcb_offsets[0]); i++)
        ok = ok && pwrite(fd, zero, sizeof(zero), bcb_offsets[i])
                       == (ssize_t)sizeof(zero);
    ok = ok && fsync(fd) == 0;
    ioctl(fd, BLKFLSBUF, 0);          /* read back from the eMMC itself */
    for (size_t i = 0; i < sizeof(bcb_offsets) / sizeof(bcb_offsets[0]); i++)
        ok = ok && pread(fd, back, sizeof(back), bcb_offsets[i])
                       == (ssize_t)sizeof(back)
                && memcmp(back, zero, sizeof(zero)) == 0;
    if (!ok)
        logf_("clear misc: %s", strerror(errno));
    close(fd);
    return ok ? 0 : -1;
}

/* -- images ------------------------------------------------------------ */

static void sha256_of(const unsigned char *data, size_t len,
                      unsigned char out[32])
{
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(&ctx, out);
}

static void hex(const unsigned char d[32], char out[65])
{
    for (int i = 0; i < 32; i++)
        sprintf(out + 2 * i, "%02x", d[i]);
}

/* Read a whole file from the stick into memory */
static unsigned char *load(const char *path, size_t *len)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return NULL;
    struct stat st;
    unsigned char *buf = NULL;
    if (fstat(fd, &st) == 0 && st.st_size > 0 &&
        (buf = malloc(st.st_size))) {
        size_t got = 0;
        while (got < (size_t)st.st_size) {
            ssize_t n = read(fd, buf + got, st.st_size - got);
            if (n <= 0)
                break;
            got += n;
        }
        if (got != (size_t)st.st_size) {
            free(buf);
            buf = NULL;
        }
        *len = got;
    }
    close(fd);
    return buf;
}

/* The digest of name in install/manifest (sha256sum format) */
static int manifest_digest(const char *dir, const char *name,
                           unsigned char out[32])
{
    char path[512], line[300];
    snprintf(path, sizeof(path), "%s/manifest", dir);
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;
    int found = -1;
    while (found && fgets(line, sizeof(line), f)) {
        char h[65], n[200];
        if (sscanf(line, "%64s %199s", h, n) != 2 || strlen(h) != 64)
            continue;
        if (strcmp(n[0] == '*' ? n + 1 : n, name) != 0)
            continue;
        found = 0;
        for (int i = 0; i < 32; i++) {
            unsigned v;
            if (sscanf(h + 2 * i, "%2x", &v) != 1)
                found = -1;
            out[i] = v;
        }
    }
    fclose(f);
    return found;
}

/* Write an image to a partition in small flushed steps and verify it by
   reading it back from the eMMC. */
static int write_image(const unsigned char *data, size_t len,
                       const char *partname)
{
    char dev[256];
    if (part_path(partname, dev, sizeof(dev)) != 0) {
        ui("partition %s not found", partname);
        return -1;
    }
    int fd = open(dev, O_RDWR);
    if (fd < 0) {
        ui("cannot open %s: %s", dev, strerror(errno));
        return -1;
    }
    double t0 = uptime();
    for (size_t off = 0; off < len; off += WRITE_STEP) {
        size_t n = len - off < WRITE_STEP ? len - off : WRITE_STEP;
        if (pwrite(fd, data + off, n, off) != (ssize_t)n ||
            fdatasync(fd) != 0) {
            ui("write to %s failed at %zu: %s", partname, off,
               strerror(errno));
            close(fd);
            return -1;
        }
        usleep(WRITE_PAUSE);
    }
    double t1 = uptime();
    ioctl(fd, BLKFLSBUF, 0);
    static unsigned char back[WRITE_STEP];
    int ok = 1;
    for (size_t off = 0; ok && off < len; off += WRITE_STEP) {
        size_t n = len - off < WRITE_STEP ? len - off : WRITE_STEP;
        ok = pread(fd, back, n, off) == (ssize_t)n &&
             memcmp(back, data + off, n) == 0;
    }
    close(fd);
    if (!ok) {
        ui("%s does not verify", partname);
        return -1;
    }
    ui("%s written (%zu bytes, %.1f s)", partname, len, t1 - t0);
    return 0;
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
            snprintf(g_stick_dev, sizeof(g_stick_dev), "%s/%s", BLOCK_DIR,
                     e->d_name);
            umount(USB_DIR);
            g_stick_mounted = 0;
            if (stick_mount() != 0)
                continue;
            char marker[320];
            snprintf(marker, sizeof(marker), "%s/%s/lk2nd.img", USB_DIR, SRC_DIR);
            if (access(marker, F_OK) == 0) {
                closedir(d);
                snprintf(dir, dirlen, "%s/%s", USB_DIR, SRC_DIR);
                return 0;
            }
            umount(USB_DIR);
            g_stick_mounted = 0;
        }
        if (d)
            closedir(d);
        sleep(1);
    }
    return -1;
}

int main(int argc, char **argv)
{
    /* Nothing may stop this program between writing the boot parts and
       clearing the recovery request */
    signal(SIGPIPE, SIG_IGN);
    signal(SIGHUP, SIG_IGN);
    signal(SIGTERM, SIG_IGN);
    signal(SIGINT, SIG_IGN);

    if (argc >= 3)
        g_pipe = atoi(argv[2]);

    ui(" ");
    ui("Installing Klipper (KlipperSnapmakerJ1-os)");
    ui("Do not switch the printer off.  It restarts by itself.");

    char dir[400];
    if (mount_stick(dir, sizeof(dir)) != 0)
        die("no USB stick with the Klipper install files found");

    int earlier = unfinished_runs();
    logf_("=== begin %s (package %s, stick %s%s, unfinished runs before: %d)",
          INSTALLER_VERSION, argc >= 4 ? argv[3] : "?", g_stick_dev,
          g_stick_rw ? "" : " read-only", earlier);
    log_boot_reason();
    if (earlier > 0) {
        /* A run before did not end: keep what tells why */
        char name[64];
        snprintf(name, sizeof(name), "last_kmsg-%d.txt", earlier);
        stick_copy("/proc/last_kmsg", name, 256 * 1024);
    }
    log_flush();

    char lk[512], lb[512];
    snprintf(lk, sizeof(lk), "%s/lk2nd.img", dir);
    snprintf(lb, sizeof(lb), "%s/linux-boot.img", dir);

    ui("Reading the install files...");
    size_t lk_len = 0, lb_len = 0;
    unsigned char *lk_data = load(lk, &lk_len);
    unsigned char *lb_data = load(lb, &lb_len);
    if (!lk_data || !lb_data)
        die("cannot read the install files on the stick");
    unsigned char got[32], want[32];
    char gh[65];
    sha256_of(lk_data, lk_len, got);
    hex(got, gh);
    logf_("lk2nd.img %zu bytes sha256 %s", lk_len, gh);
    if (memcmp(got, SHA256_LK2ND, 32) != 0)
        die("lk2nd.img on the stick is damaged (checksum)");
    sha256_of(lb_data, lb_len, got);
    hex(got, gh);
    logf_("linux-boot.img %zu bytes sha256 %s", lb_len, gh);
    if (manifest_digest(dir, "linux-boot.img", want) != 0)
        die("install/manifest on the stick is missing or damaged");
    if (memcmp(got, want, 32) != 0)
        die("linux-boot.img on the stick is damaged (checksum)");

    /* The stick is not touched while the eMMC is written */
    stick_umount();

    /* From here on boot parts get overwritten: no return to the stock
       system is possible, so failures continue trying rather than aborting
       to a half-written state. */
    ui("Writing the boot loader...");
    if (write_image(lk_data, lk_len, "boot") != 0 &&
        write_image(lk_data, lk_len, "boot") != 0)
        die("boot loader not written");
    stick_mount();                    /* keep the progress on the stick */
    stick_umount();

    ui("Writing the Linux boot partition...");
    if (umount("/cache") != 0)        /* drop the recovery handle on cache */
        logf_("umount /cache: %s", strerror(errno));
    if (write_image(lb_data, lb_len, "cache") != 0) {
        ui("FATAL: cache half written, retrying once...");
        if (write_image(lb_data, lb_len, "cache") != 0)
            die("Linux boot partition not written");
    }

    /* The recovery package was on the old cache: a recovery started again
       would find nothing and wait for a key, so the request must be gone */
    int i;
    for (i = 0; clear_bcb() != 0; i++) {
        ui("could not clear the recovery request, retrying...");
        if (i >= 10)
            break;
        sleep(1);
    }
    logf_("recovery request %s", i <= 10 ? "cleared" : "NOT cleared");

    ui("Done.  Restarting into the Klipper installer...");
    /* The recovery log of this run, for a run that went wrong after all */
    stick_mount();
    char name[64];
    snprintf(name, sizeof(name), "recovery-log-%d.txt", earlier + 1);
    stick_copy("/tmp/recovery.log", name, 256 * 1024);
    finish("ok");
    return 0;
}
