.class public Lcom/snapmaker/j1/MainActivity;
.super Landroid/app/Activity;

# Status screen with the way back to Snapmaker; starts the trigger once.

.field private text:Landroid/widget/TextView;

.field private static started:Z

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .locals 4
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    new-instance v0, Landroid/widget/LinearLayout;
    invoke-direct {v0, p0}, Landroid/widget/LinearLayout;-><init>(Landroid/content/Context;)V
    const/4 v1, 0x1                # VERTICAL
    invoke-virtual {v0, v1}, Landroid/widget/LinearLayout;->setOrientation(I)V
    const/16 v1, 0x11              # Gravity.CENTER
    invoke-virtual {v0, v1}, Landroid/widget/LinearLayout;->setGravity(I)V

    new-instance v1, Landroid/widget/TextView;
    invoke-direct {v1, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    const/high16 v2, 0x41c00000    # 24.0f
    invoke-virtual {v1, v2}, Landroid/widget/TextView;->setTextSize(F)V
    const/16 v2, 0x11
    invoke-virtual {v1, v2}, Landroid/widget/TextView;->setGravity(I)V
    const-string v2, "Klipper installation\n\nPreparing the installer..."
    invoke-virtual {v1, v2}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    iput-object v1, p0, Lcom/snapmaker/j1/MainActivity;->text:Landroid/widget/TextView;
    invoke-virtual {v0, v1}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v1, Landroid/widget/Button;
    invoke-direct {v1, p0}, Landroid/widget/Button;-><init>(Landroid/content/Context;)V
    const/high16 v2, 0x41a00000    # 20.0f
    invoke-virtual {v1, v2}, Landroid/widget/Button;->setTextSize(F)V
    const-string v2, "Back to Snapmaker"
    invoke-virtual {v1, v2}, Landroid/widget/Button;->setText(Ljava/lang/CharSequence;)V
    new-instance v2, Lcom/snapmaker/j1/Revert;
    invoke-direct {v2, p0}, Lcom/snapmaker/j1/Revert;-><init>(Lcom/snapmaker/j1/MainActivity;)V
    invoke-virtual {v1, v2}, Landroid/widget/Button;->setOnClickListener(Landroid/view/View$OnClickListener;)V
    invoke-virtual {v0, v1}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    invoke-virtual {p0, v0}, Landroid/app/Activity;->setContentView(Landroid/view/View;)V

    sget-boolean v1, Lcom/snapmaker/j1/MainActivity;->started:Z
    if-nez v1, :done
    const/4 v1, 0x1
    sput-boolean v1, Lcom/snapmaker/j1/MainActivity;->started:Z
    new-instance v1, Ljava/lang/Thread;
    new-instance v2, Lcom/snapmaker/j1/Trigger;
    invoke-direct {v2, p0}, Lcom/snapmaker/j1/Trigger;-><init>(Lcom/snapmaker/j1/MainActivity;)V
    invoke-direct {v1, v2}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    :done
    return-void
.end method

# Show a message (from any thread).
.method public status(Ljava/lang/String;)V
    .locals 1
    new-instance v0, Lcom/snapmaker/j1/Status;
    invoke-direct {v0, p0, p1}, Lcom/snapmaker/j1/Status;-><init>(Lcom/snapmaker/j1/MainActivity;Ljava/lang/String;)V
    invoke-virtual {p0, v0}, Landroid/app/Activity;->runOnUiThread(Ljava/lang/Runnable;)V
    return-void
.end method

.method public setText(Ljava/lang/String;)V
    .locals 1
    iget-object v0, p0, Lcom/snapmaker/j1/MainActivity;->text:Landroid/widget/TextView;
    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    return-void
.end method
