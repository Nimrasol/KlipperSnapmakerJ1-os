#!/usr/bin/env python3
# Sign an Android boot image for the verified boot of the SC20-W bootloader
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Implements the AndroidVerifiedBootSignature of AOSP's boot_signer:
#
#   AndroidVerifiedBootSignature ::= SEQUENCE {
#       formatVersion ::= INTEGER (1),
#       certificate ::= Certificate,
#       algorithmIdentifier ::= SEQUENCE { OID sha256WithRSAEncryption },
#       authenticatedAttributes ::= SEQUENCE {
#           target ::= PrintableString ("/boot"),
#           length ::= INTEGER },
#       signature ::= OCTET STRING }
#
# The signature is SHA256withRSA over the image followed by the DER encoded
# authenticated attributes.  The bootloader of the J1 display trusts the
# public AOSP "verity" test key (build/target/product/security/verity.*),
# see docs/ANALYSIS.md.
import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootimg  # noqa: E402

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

SHA256_WITH_RSA = bytes.fromhex("06092a864886f70d01010b")


def der_length(n):
    if n < 0x80:
        return bytes([n])
    body = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(body)]) + body


def der(tag, body):
    return bytes([tag]) + der_length(len(body)) + body


def der_int(value):
    body = value.to_bytes(value.bit_length() // 8 + 1, "big", signed=False)
    return der(0x02, body)


def authenticated_attributes(target, length):
    return der(0x30, der(0x13, target.encode()) + der_int(length))


def sign(image, key, cert, target="/boot"):
    length = bootimg.image_size(bootimg.read_header(image))
    attrs = authenticated_attributes(target, length)
    signature = key.sign(image[:length] + attrs, padding.PKCS1v15(),
                         hashes.SHA256())
    # Without parameters (no NULL), as written by AOSP's boot_signer
    algorithm = der(0x30, SHA256_WITH_RSA)
    body = (der_int(1) + cert.public_bytes(serialization.Encoding.DER)
            + algorithm + attrs + der(0x04, signature))
    return image[:length], der(0x30, body)


def load_key(path):
    data = open(path, "rb").read()
    if data.startswith(b"-----"):
        return serialization.load_pem_private_key(data, None)
    return serialization.load_der_private_key(data, None)


def load_cert(path):
    data = open(path, "rb").read()
    if data.startswith(b"-----"):
        return x509.load_pem_x509_certificate(data)
    return x509.load_der_x509_certificate(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="unsigned boot image")
    parser.add_argument("key", help="private key (verity.pk8 or PEM)")
    parser.add_argument("cert", help="certificate (verity.x509.pem)")
    parser.add_argument("out", help="signed boot image")
    parser.add_argument("--target", default="/boot")
    parser.add_argument("--partition-size", type=int,
                        help="pad the result to the partition size")
    args = parser.parse_args()
    image = open(args.image, "rb").read()
    body, signature = sign(image, load_key(args.key), load_cert(args.cert),
                           args.target)
    out = body + signature
    if args.partition_size:
        if len(out) > args.partition_size:
            sys.exit("signed image larger than the partition")
        out += b"\0" * (args.partition_size - len(out))
    with open(args.out, "wb") as f:
        f.write(out)
    print("%s: %d bytes, signature %d bytes" % (args.out, len(out),
                                                 len(signature)))


if __name__ == "__main__":
    sys.exit(main())
