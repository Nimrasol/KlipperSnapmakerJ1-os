.class public Lcom/nimrasol/j1installer/MainActivity;
.super Landroid/app/Activity;

# Shows what the installer does and starts it once.

.field private text:Landroid/widget/TextView;

.field private static started:Z

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .locals 3
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    new-instance v0, Landroid/widget/TextView;
    invoke-direct {v0, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    const/high16 v1, 0x41c00000    # 24.0f
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setTextSize(F)V
    const/16 v1, 0x11              # Gravity.CENTER
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setGravity(I)V
    const-string v1, "Klipper installation\n\nStarting the installer..."
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    iput-object v0, p0, Lcom/nimrasol/j1installer/MainActivity;->text:Landroid/widget/TextView;
    invoke-virtual {p0, v0}, Landroid/app/Activity;->setContentView(Landroid/view/View;)V

    sget-boolean v1, Lcom/nimrasol/j1installer/MainActivity;->started:Z
    if-nez v1, :done
    const/4 v1, 0x1
    sput-boolean v1, Lcom/nimrasol/j1installer/MainActivity;->started:Z
    new-instance v1, Ljava/lang/Thread;
    new-instance v2, Lcom/nimrasol/j1installer/Go;
    invoke-direct {v2, p0}, Lcom/nimrasol/j1installer/Go;-><init>(Lcom/nimrasol/j1installer/MainActivity;)V
    invoke-direct {v1, v2}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    :done
    return-void
.end method

# Show a message (from any thread).
.method public status(Ljava/lang/String;)V
    .locals 1
    new-instance v0, Lcom/nimrasol/j1installer/Status;
    invoke-direct {v0, p0, p1}, Lcom/nimrasol/j1installer/Status;-><init>(Lcom/nimrasol/j1installer/MainActivity;Ljava/lang/String;)V
    invoke-virtual {p0, v0}, Landroid/app/Activity;->runOnUiThread(Ljava/lang/Runnable;)V
    return-void
.end method

.method public setText(Ljava/lang/String;)V
    .locals 1
    iget-object v0, p0, Lcom/nimrasol/j1installer/MainActivity;->text:Landroid/widget/TextView;
    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    return-void
.end method
