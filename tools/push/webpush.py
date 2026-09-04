#!/usr/bin/env python3
"""The Web Push sender: RFC 8291 encryption and RFC 8292 authentication, from first principles.

    python3 tools/push/webpush.py --self-test          # against the RFC's own vectors
    python3 tools/push/webpush.py --keys               # a fresh VAPID pair for one pair of phones
    python3 tools/push/webpush.py --send sub.json --kind feeling --from noor

This exists because of one rule the brief sets and this file has to keep: **a push payload may
carry the event kind and who sent it, and nothing else**. Not the text, not the feeling's name, not
a preview, not a count. The note itself is fetched over the tailnet when the app is opened, by the
app, from the other phone. So the payload this builds is exactly two short fields, and
`payload_for` is the only place one is made — there is nowhere else in the tree to widen it.

The push service is a stranger. It sees an encrypted blob, its length, and the endpoint. That is
the whole reason the payload is encrypted at all: the two of them are not asking a push service to
be discreet, they are making it unable to read anything.
"""
import argparse
import base64
import json
import os
import struct
import sys
import time

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils as asym_utils
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand

# what a payload is allowed to contain, and the only place it is decided
ALLOWED_KEYS = ("kind", "from")


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def unb64(s):
    if isinstance(s, str):
        s = s.encode()
    return base64.urlsafe_b64decode(s + b"=" * (-len(s) % 4))


def hkdf(salt, ikm, info, length):
    """RFC 5869 with SHA-256, written out because both RFCs specify it exactly."""
    import hmac as _hmac
    import hashlib
    prk = _hmac.new(salt, ikm, hashlib.sha256).digest()
    out = b""
    t = b""
    counter = 1
    while len(out) < length:
        t = _hmac.new(prk, t + info + bytes([counter]), hashlib.sha256).digest()
        out += t
        counter += 1
    return out[:length]


def payload_for(kind, sender):
    """The whole payload. Two fields, both short, neither of them content.

    Anything else a caller passes is dropped here rather than encrypted, because a payload that
    can grow is a payload that will.
    """
    return json.dumps({"kind": str(kind)[:32], "from": str(sender)[:16]}, separators=(",", ":")).encode()


def encrypt(payload, p256dh, auth, salt=None, private=None, record_size=4096):
    """RFC 8291 §3: aes128gcm, one record, the sender's public key in the header.

    [salt 16][record size 4][key length 1][sender public key 65][ciphertext]
    """
    client_public = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), p256dh)
    private = private or ec.generate_private_key(ec.SECP256R1())
    sender_public = private.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    shared = private.exchange(ec.ECDH(), client_public)
    salt = salt or os.urandom(16)

    # the pseudo-random key combines the two public keys, so a record can only be read by the
    # subscription it was made for
    ikm_info = b"WebPush: info\x00" + p256dh + sender_public
    ikm = hkdf(auth, shared, ikm_info, 32)
    key = hkdf(salt, ikm, b"Content-Encoding: aes128gcm\x00", 16)
    nonce = hkdf(salt, ikm, b"Content-Encoding: nonce\x00", 12)

    # one record, padded with the 0x02 delimiter that says "this is the last one"
    body = payload + b"\x02"
    ciphertext = AESGCM(key).encrypt(nonce, body, None)
    header = salt + struct.pack("!IB", record_size, len(sender_public)) + sender_public
    return header + ciphertext


def decrypt(block, private_bytes, auth):
    """The receiving half, for the self-test: what the phone does with the block."""
    salt = block[:16]
    key_len = block[20]
    sender_public = block[21:21 + key_len]
    ciphertext = block[21 + key_len:]
    private = ec.derive_private_key(int.from_bytes(private_bytes, "big"), ec.SECP256R1())
    receiver_public = private.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    shared = private.exchange(ec.ECDH(), ec.EllipticCurvePublicKey.from_encoded_point(
        ec.SECP256R1(), sender_public))
    ikm = hkdf(auth, shared, b"WebPush: info\x00" + receiver_public + sender_public, 32)
    key = hkdf(salt, ikm, b"Content-Encoding: aes128gcm\x00", 16)
    nonce = hkdf(salt, ikm, b"Content-Encoding: nonce\x00", 12)
    plain = AESGCM(key).decrypt(nonce, ciphertext, None)
    return plain.rstrip(b"\x02")


# ---------------------------------------------------------------- VAPID (RFC 8292)
def vapid_keys():
    private = ec.generate_private_key(ec.SECP256R1())
    return {
        "private": b64(private.private_numbers().private_value.to_bytes(32, "big")),
        "public": b64(private.public_key().public_bytes(
            serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)),
    }


def vapid_header(endpoint, private_b64, subject, ttl_seconds=12 * 3600):
    """The Authorization header: a JWT the push service checks, signed with the sender's key."""
    from urllib.parse import urlparse
    origin = urlparse(endpoint)
    claims = {
        "aud": f"{origin.scheme}://{origin.netloc}",
        "exp": int(time.time()) + ttl_seconds,
        "sub": subject,
    }
    header = b64(json.dumps({"typ": "JWT", "alg": "ES256"}, separators=(",", ":")).encode())
    body = b64(json.dumps(claims, separators=(",", ":")).encode())
    signing_input = f"{header}.{body}".encode()
    private = ec.derive_private_key(int.from_bytes(unb64(private_b64), "big"), ec.SECP256R1())
    der = private.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = asym_utils.decode_dss_signature(der)
    signature = b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    public = b64(private.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint))
    return {
        "Authorization": f"vapid t={header}.{body}.{signature}, k={public}",
        "Content-Encoding": "aes128gcm",
        "TTL": "43200",
        "Urgency": "normal",
    }


# ---------------------------------------------------------------- the RFC's own vectors
# RFC 8291 section 5. If this stops passing, the encryption is wrong, whatever the phones say.
VECTOR = {
    "plaintext": b"When I grow up, I want to be a watermelon",
    "receiver_private": "q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94",
    "receiver_public": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
    "auth": "BTBZMqHH6r4Tts7J_aSIgg",
    "sender_private": "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw",
    "salt": "DGv6ra1nlYgDCS1FRnbzlw",
    "record": ("DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27ml"
               "mlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPT"
               "pK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN"),
}


def self_test():
    ok = True
    receiver_private = unb64(VECTOR["receiver_private"])
    sender_private = ec.derive_private_key(int.from_bytes(unb64(VECTOR["sender_private"]), "big"),
                                           ec.SECP256R1())
    block = encrypt(VECTOR["plaintext"], unb64(VECTOR["receiver_public"]), unb64(VECTOR["auth"]),
                    salt=unb64(VECTOR["salt"]), private=sender_private)
    want = unb64(VECTOR["record"])
    same = block == want
    print(f"RFC 8291 §5 record: {'matches' if same else 'DOES NOT MATCH'}")
    if not same:
        print(f"  got  {b64(block)}")
        print(f"  want {VECTOR['record']}")
        ok = False

    back = decrypt(block, receiver_private, unb64(VECTOR["auth"]))
    round_trip = back == VECTOR["plaintext"]
    print(f"round trip: {'plaintext recovered' if round_trip else 'FAILED'}")
    ok = ok and round_trip

    # and the rule this file exists to keep
    payload = payload_for("feeling", "noor")
    fields = json.loads(payload)
    extra = set(fields) - set(ALLOWED_KEYS)
    print(f"payload: {payload.decode()} ({len(payload)} bytes)")
    if extra:
        print(f"  a payload carried {sorted(extra)}, which it may not")
        ok = False
    else:
        print(f"payload carries only {list(ALLOWED_KEYS)}: yes")

    keys = vapid_keys()
    head = vapid_header("https://push.example.net/x/abc123", keys["private"], "mailto:two@phones")
    parts = head["Authorization"].split("t=")[1].split(",")[0].split(".")
    print(f"VAPID header: ES256 JWT in three parts, {len(parts)} parts, k= present: "
          f"{'k=' in head['Authorization']}")
    ok = ok and len(parts) == 3 and "k=" in head["Authorization"]
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--keys", action="store_true")
    ap.add_argument("--send", help="a subscription JSON file: {endpoint, keys:{p256dh, auth}}")
    ap.add_argument("--kind", default="feeling")
    ap.add_argument("--from", dest="sender", default="noor")
    ap.add_argument("--vapid-private", default=os.environ.get("VAPID_PRIVATE", ""))
    ap.add_argument("--subject", default="mailto:two@phones")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    if args.self_test:
        return 0 if self_test() else 1
    if args.keys:
        print(json.dumps(vapid_keys(), indent=1))
        return 0
    if args.send:
        sub = json.loads(open(args.send).read())
        block = encrypt(payload_for(args.kind, args.sender),
                        unb64(sub["keys"]["p256dh"]), unb64(sub["keys"]["auth"]))
        headers = vapid_header(sub["endpoint"], args.vapid_private, args.subject) if args.vapid_private else {}
        headers["Content-Length"] = str(len(block))
        report = {"endpoint": sub["endpoint"], "bytes": len(block), "headers": headers}
        if args.out:
            open(args.out, "wb").write(block)
            report["body"] = args.out
        print(json.dumps(report, indent=1))
        return 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
