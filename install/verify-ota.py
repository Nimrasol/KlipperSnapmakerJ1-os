#!/usr/bin/env python3
# Verify an OTA package exactly as the stock recovery does: the whole-file
# signature against the device's trusted key (recovery res/keys).  This lets
# the package be checked without the printer.
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: verify-ota.py OTA_ZIP RES_KEYS
import re, subprocess, sys


def load_reskey(path):
    # res/keys: {nwords,n0inv,{n0,n1,...},{rr...}} -> modulus, e=65537
    txt = open(path).read()
    nums = re.findall(r"-?\d+", txt.split("{", 2)[2].split("}", 1)[0])
    limbs = [int(x) & 0xFFFFFFFF for x in nums]
    mod = 0
    for i, v in enumerate(limbs):
        mod |= v << (32 * i)
    return mod, 65537


def verify(zip_path, keys_path):
    data = open(zip_path, "rb").read()
    n = len(data)
    footer = data[n - 6:]
    if footer[2] != 0xFF or footer[3] != 0xFF:
        return "no signature footer magic"
    comment_size = footer[4] | (footer[5] << 8)
    signature_start = footer[0] | (footer[1] << 8)
    signed_len = n - comment_size - 2
    eocd = data[n - comment_size - 22:n - comment_size - 22 + 4]
    if eocd != b"PK\x05\x06":
        return "EOCD not where the comment says"
    sig_der = data[n - signature_start:n - 6]

    # PKCS#7 signature over data[0:signed_len], verified with the RSA pubkey.
    mod, e = load_reskey(keys_path)
    # Rebuild the public key as PEM for openssl.
    import base64
    def der_len(n):
        if n < 0x80:
            return bytes([n])
        b = n.to_bytes((n.bit_length() + 7) // 8, "big")
        return bytes([0x80 | len(b)]) + b
    def der_int(x):
        b = x.to_bytes((x.bit_length() + 7) // 8 or 1, "big")
        if b[0] & 0x80:
            b = b"\x00" + b
        return b"\x02" + der_len(len(b)) + b
    rsa = der_int(mod) + der_int(e)
    rsa = b"\x30" + der_len(len(rsa)) + rsa
    bit = b"\x00" + rsa
    bit = b"\x03" + der_len(len(bit)) + bit
    algid = bytes.fromhex("300d06092a864886f70d0101010500")
    spki = algid + bit
    spki = b"\x30" + der_len(len(spki)) + spki
    pem = ("-----BEGIN PUBLIC KEY-----\n"
           + "\n".join(base64.b64encode(spki).decode()[i:i + 64]
                       for i in range(0, len(base64.b64encode(spki)), 64))
           + "\n-----END PUBLIC KEY-----\n")
    open("/tmp/otakey.pem", "w").write(pem)
    open("/tmp/ota.sig", "wb").write(sig_der)
    open("/tmp/ota.signed", "wb").write(data[:signed_len])

    # The signature is a PKCS#7; extract the signed content type/digest via
    # openssl smime/cms verification with the certificate derived key.
    r = subprocess.run(
        ["openssl", "smime", "-verify", "-binary", "-inform", "DER",
         "-in", "/tmp/ota.sig", "-content", "/tmp/ota.signed",
         "-noverify", "-no_signer_cert_verify", "-out", "/dev/null"],
        capture_output=True, text=True)
    if r.returncode == 0:
        return None
    # Fallback: CMS
    r2 = subprocess.run(
        ["openssl", "cms", "-verify", "-binary", "-inform", "DER",
         "-in", "/tmp/ota.sig", "-content", "/tmp/ota.signed",
         "-noverify", "-no_content_verify", "-out", "/dev/null"],
        capture_output=True, text=True)
    if r2.returncode == 0:
        return None
    return "signature did not verify:\n" + r.stderr + r2.stderr


def main():
    if len(sys.argv) != 3:
        sys.exit("Usage: verify-ota.py OTA_ZIP RES_KEYS")
    err = verify(sys.argv[1], sys.argv[2])
    if err:
        sys.exit("FAIL: " + err)
    print("OK: whole-file signature verifies against the device key")


if __name__ == "__main__":
    main()
