.class public Lcom/nimrasol/j1installer/Status;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

.field private final a:Lcom/nimrasol/j1installer/MainActivity;
.field private final s:Ljava/lang/String;

.method public constructor <init>(Lcom/nimrasol/j1installer/MainActivity;Ljava/lang/String;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/nimrasol/j1installer/Status;->a:Lcom/nimrasol/j1installer/MainActivity;
    iput-object p2, p0, Lcom/nimrasol/j1installer/Status;->s:Ljava/lang/String;
    return-void
.end method

.method public run()V
    .locals 2
    iget-object v0, p0, Lcom/nimrasol/j1installer/Status;->a:Lcom/nimrasol/j1installer/MainActivity;
    iget-object v1, p0, Lcom/nimrasol/j1installer/Status;->s:Ljava/lang/String;
    invoke-virtual {v0, v1}, Lcom/nimrasol/j1installer/MainActivity;->setText(Ljava/lang/String;)V
    return-void
.end method
