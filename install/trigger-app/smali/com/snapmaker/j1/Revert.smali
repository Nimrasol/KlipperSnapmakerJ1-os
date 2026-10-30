.class public Lcom/snapmaker/j1/Revert;
.super Ljava/lang/Object;
.implements Landroid/view/View$OnClickListener;
.implements Ljava/lang/Runnable;

# "Back to Snapmaker": remove this update of com.snapmaker.j1, which brings
# back the stock app kept in /system/app/j1 (it then updates itself again
# from a stock update package).  Removes the installer app as well.

.field private final a:Lcom/snapmaker/j1/MainActivity;

.method public constructor <init>(Lcom/snapmaker/j1/MainActivity;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/snapmaker/j1/Revert;->a:Lcom/snapmaker/j1/MainActivity;
    return-void
.end method

.method public onClick(Landroid/view/View;)V
    .locals 2
    iget-object v0, p0, Lcom/snapmaker/j1/Revert;->a:Lcom/snapmaker/j1/MainActivity;
    const-string v1, "Restoring the Snapmaker app..."
    invoke-virtual {v0, v1}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    new-instance v0, Ljava/lang/Thread;
    invoke-direct {v0, p0}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    invoke-virtual {v0}, Ljava/lang/Thread;->start()V
    return-void
.end method

.method public run()V
    .locals 5
    iget-object v0, p0, Lcom/snapmaker/j1/Revert;->a:Lcom/snapmaker/j1/MainActivity;

    :try_start_0
    # PackageManager.deletePackage (hidden API, DELETE_PACKAGES); pm cannot
    # do this for an app caller.  For com.snapmaker.j1 it removes the update.
    invoke-virtual {v0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;
    move-result-object v1
    const/4 v2, 0x0
    const/4 v3, 0x0
    const-string v4, "com.nimrasol.j1installer"
    invoke-virtual {v1, v4, v2, v3}, Landroid/content/pm/PackageManager;->deletePackage(Ljava/lang/String;Landroid/content/pm/IPackageDeleteObserver;I)V
    const-wide/16 v1, 0xbb8    # 3 s
    invoke-static {v1, v2}, Ljava/lang/Thread;->sleep(J)V
    invoke-virtual {v0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;
    move-result-object v1
    const/4 v2, 0x0
    const-string v4, "com.snapmaker.j1"
    invoke-virtual {v1, v4, v2, v3}, Landroid/content/pm/PackageManager;->deletePackage(Ljava/lang/String;Landroid/content/pm/IPackageDeleteObserver;I)V
    # only seen if this process survives the removal for a while
    const-wide/16 v1, 0x3a98    # 15 s
    invoke-static {v1, v2}, Ljava/lang/Thread;->sleep(J)V
    const-string v1, "Back to Snapmaker did not finish.\nSwitch the printer off and on."
    invoke-virtual {v0, v1}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v1
    const-string v2, "Back to Snapmaker FAILED\n\n"
    invoke-virtual {v1}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v2, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Lcom/snapmaker/j1/MainActivity;->status(Ljava/lang/String;)V
    return-void
.end method
