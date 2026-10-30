.class public Lcom/snapmaker/j1/Trigger;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

# Install the installer app (bundled as an asset) with pm, as the stock app
# installs its updates, and start it.  This package runs with the app user
# id of the stock app, which may install packages (platform signature) but
# not use the recovery; the installer app joins the system user id for that.

.field private final a:Lcom/snapmaker/j1/MainActivity;

.method public constructor <init>(Lcom/snapmaker/j1/MainActivity;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/snapmaker/j1/Trigger;->a:Lcom/snapmaker/j1/MainActivity;
    return-void
.end method

# Run a command, return its output (stdout and stderr).
.method public static exec([Ljava/lang/String;)Ljava/lang/String;
    .locals 4
    new-instance v0, Ljava/lang/ProcessBuilder;
    invoke-direct {v0, p0}, Ljava/lang/ProcessBuilder;-><init>([Ljava/lang/String;)V
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/ProcessBuilder;->redirectErrorStream(Z)Ljava/lang/ProcessBuilder;
    invoke-virtual {v0}, Ljava/lang/ProcessBuilder;->start()Ljava/lang/Process;
    move-result-object v0
    invoke-virtual {v0}, Ljava/lang/Process;->getInputStream()Ljava/io/InputStream;
    move-result-object v1
    new-instance v2, Ljava/util/Scanner;
    invoke-direct {v2, v1}, Ljava/util/Scanner;-><init>(Ljava/io/InputStream;)V
    const-string v3, "\\A"
    invoke-virtual {v2, v3}, Ljava/util/Scanner;->useDelimiter(Ljava/lang/String;)Ljava/util/Scanner;
    invoke-virtual {v2}, Ljava/util/Scanner;->hasNext()Z
    move-result v3
    if-eqz v3, :empty
    invoke-virtual {v2}, Ljava/util/Scanner;->next()Ljava/lang/String;
    move-result-object v3
    goto :wait
    :empty
    const-string v3, ""
    :wait
    invoke-virtual {v0}, Ljava/lang/Process;->waitFor()I
    return-object v3
.end method

.method public run()V
    .locals 7
    iget-object v0, p0, Lcom/snapmaker/j1/Trigger;->a:Lcom/snapmaker/j1/MainActivity;

    :try_start_0
    # copy the installer app out of the assets
    new-instance v1, Ljava/io/File;
    invoke-virtual {v0}, Landroid/content/Context;->getFilesDir()Ljava/io/File;
    move-result-object v2
    const-string v3, "installer.apk"
    invoke-direct {v1, v2, v3}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    invoke-virtual {v0}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;
    move-result-object v2
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

    # pm install -r -i com.snapmaker.j1 --user 0 <apk>, like the stock app
    # (an app caller has to name the installer package)
    const/16 v2, 0x8
    new-array v2, v2, [Ljava/lang/String;
    const/4 v3, 0x0
    const-string v4, "pm"
    aput-object v4, v2, v3
    const/4 v3, 0x1
    const-string v4, "install"
    aput-object v4, v2, v3
    const/4 v3, 0x2
    const-string v4, "-r"
    aput-object v4, v2, v3
    const/4 v3, 0x3
    const-string v4, "-i"
    aput-object v4, v2, v3
    const/4 v3, 0x4
    const-string v4, "com.snapmaker.j1"
    aput-object v4, v2, v3
    const/4 v3, 0x5
    const-string v4, "--user"
    aput-object v4, v2, v3
    const/4 v3, 0x6
    const-string v4, "0"
    aput-object v4, v2, v3
    const/4 v3, 0x7
    invoke-virtual {v1}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;
    move-result-object v4
    aput-object v4, v2, v3
    invoke-static {v2}, Lcom/snapmaker/j1/Trigger;->exec([Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    const-string v3, "Success"
    invoke-virtual {v2, v3}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v3
    if-eqz v3, :failed

    # start it
    new-instance v3, Landroid/content/Intent;
    invoke-direct {v3}, Landroid/content/Intent;-><init>()V
    const-string v4, "com.nimrasol.j1installer"
    const-string v5, "com.nimrasol.j1installer.MainActivity"
    invoke-virtual {v3, v4, v5}, Landroid/content/Intent;->setClassName(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;
    const/high16 v4, 0x10000000    # FLAG_ACTIVITY_NEW_TASK
    invoke-virtual {v3, v4}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;
    invoke-virtual {v0, v3}, Landroid/app/Activity;->startActivity(Landroid/content/Intent;)V
    const-string v2, "Klipper installation\n\nThe installer did not restart the printer.\nSwitch the printer off and on to try again,\nor go back to Snapmaker."
    invoke-virtual {v0, v2}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :failed
    const-string v3, "Klipper installation FAILED\n\nInstalling the installer app:\n"
    invoke-virtual {v3, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0, v2}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    return-void

    :catch_0
    move-exception v1
    const-string v2, "klipper"
    const-string v3, "trigger failed"
    invoke-static {v2, v3, v1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    const-string v2, "Klipper installation FAILED\n\n"
    invoke-virtual {v1}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v2, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0, v2}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    return-void
.end method
