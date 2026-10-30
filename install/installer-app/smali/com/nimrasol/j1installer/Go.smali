.class public Lcom/nimrasol/j1installer/Go;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

# Copy the OTA package (bundled as an asset) to /cache/recovery and hand it
# to the standard Android RecoverySystem, which reboots into the recovery to
# install it.  The SELinux policy lets system_app create files in
# /cache/recovery (not in /cache itself) and use the recovery service.
# On failure the message stays on screen for a while, then the trigger app
# (with its way back to Snapmaker) is shown again.

.field private final a:Lcom/nimrasol/j1installer/MainActivity;

.method public constructor <init>(Lcom/nimrasol/j1installer/MainActivity;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/nimrasol/j1installer/Go;->a:Lcom/nimrasol/j1installer/MainActivity;
    return-void
.end method

.method public run()V
    .locals 7
    iget-object v0, p0, Lcom/nimrasol/j1installer/Go;->a:Lcom/nimrasol/j1installer/MainActivity;

    :try_start_0
    new-instance v1, Ljava/io/File;
    const-string v2, "/cache/recovery/klipper-ota.zip"
    invoke-direct {v1, v2}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    invoke-virtual {v0}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;
    move-result-object v2
    const-string v3, "klipper-ota.zip"
    invoke-virtual {v2, v3}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v2
    new-instance v3, Ljava/io/FileOutputStream;
    invoke-direct {v3, v1}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V
    const v4, 0x10000
    new-array v4, v4, [B
    :copy
    invoke-virtual {v2, v4}, Ljava/io/InputStream;->read([B)I
    move-result v5
    if-ltz v5, :copied
    const/4 v6, 0x0
    invoke-virtual {v3, v4, v6, v5}, Ljava/io/FileOutputStream;->write([BII)V
    goto :copy
    :copied
    invoke-virtual {v3}, Ljava/io/FileOutputStream;->close()V
    invoke-virtual {v2}, Ljava/io/InputStream;->close()V

    const-string v2, "Klipper installation\n\nRestarting into the installer...\nLeave the USB stick plugged in."
    invoke-virtual {v0, v2}, Lcom/nimrasol/j1installer/MainActivity;->status(Ljava/lang/String;)V
    invoke-static {v0, v1}, Landroid/os/RecoverySystem;->installPackage(Landroid/content/Context;Ljava/io/File;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v1
    const-string v2, "klipper"
    const-string v3, "install failed"
    invoke-static {v2, v3, v1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    const-string v2, "Klipper installation FAILED\n\n"
    invoke-virtual {v1}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v2, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0, v2}, Lcom/nimrasol/j1installer/MainActivity;->status(Ljava/lang/String;)V
    const-wide/16 v2, 0x7530    # 30 s
    :try_start_1
    invoke-static {v2, v3}, Ljava/lang/Thread;->sleep(J)V
    :try_end_1
    .catch Ljava/lang/InterruptedException; {:try_start_1 .. :try_end_1} :catch_1
    :catch_1
    invoke-virtual {v0}, Landroid/app/Activity;->finish()V
    return-void
.end method
