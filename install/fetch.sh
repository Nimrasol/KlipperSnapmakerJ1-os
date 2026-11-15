# The public AOSP keys and the signer of the installation package, from
# android.googlesource.com, checked against fixed digests and cached
# (sourced by build-ota.sh and build-app.sh)
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/j1-ota"
SECURITY=build/+/refs/tags/android-7.1.2_r39/target/product/security
# signapk from 6.0.1: bundles bouncycastle, no conscrypt native dependency;
# the whole-file OTA format it emits is the one the recovery expects.
SIGNAPK=prebuilts/sdk/+/refs/tags/android-6.0.1_r81/tools/lib/signapk.jar

# gfetch NAME   (into $CACHE/NAME)
gfetch() {
    local path sha
    case "$1" in
        testkey.x509.pem)  path=$SECURITY/$1 sha=a4384ba815b9499a5ce349b4e33c1755278873fe2eac150a068823f526e6dbde ;;
        testkey.pk8)       path=$SECURITY/$1 sha=495675d32e89a149d5abe191f4e9c0e218b9068714e9b53a7c91e164a0741a23 ;;
        platform.x509.pem) path=$SECURITY/$1 sha=9837de028f460c35cc8d3fa45f14eecce30f6fbfe4b93d399aef1acb80c20d14 ;;
        platform.pk8)      path=$SECURITY/$1 sha=1ad8ef556870edb70f69a9d3c112544c07de5162ba440d84d33f8bb0c5962875 ;;
        signapk.jar)       path=$SIGNAPK     sha=ae6db2714d7ac819154420c00cc9b2575ab02e12a55b2f09dca03c1850557a6d ;;
        *) echo "gfetch: unknown file $1" >&2; return 1 ;;
    esac
    mkdir -p "$CACHE"
    echo "$sha  $CACHE/$1" | sha256sum -c --status 2>/dev/null && return 0
    echo "fetch $1"
    curl -fsSL "https://android.googlesource.com/platform/$path?format=TEXT" \
        -o "$CACHE/$1.b64"
    base64 -d "$CACHE/$1.b64" > "$CACHE/$1.new"
    rm -f "$CACHE/$1.b64"
    echo "$sha  $CACHE/$1.new" | sha256sum -c --quiet \
        || { rm -f "$CACHE/$1.new"; echo "gfetch: $1 has the wrong digest" >&2; return 1; }
    mv "$CACHE/$1.new" "$CACHE/$1"
}
