.class public Lcom/snapmaker/j1/Replaced;
.super Landroid/content/BroadcastReceiver;

# After the stock flow replaced the app: show the status screen, which
# starts the trigger.

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V
    return-void
.end method

.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .locals 2
    new-instance v0, Landroid/content/Intent;
    const-class v1, Lcom/snapmaker/j1/MainActivity;
    invoke-direct {v0, p1, v1}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V
    const/high16 v1, 0x10000000    # FLAG_ACTIVITY_NEW_TASK
    invoke-virtual {v0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;
    invoke-virtual {p1, v0}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V
    return-void
.end method
