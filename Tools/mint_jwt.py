#!/usr/bin/env python3
"""Mints a Supabase-style access token for local testing: mint_jwt.py <secret> <user-uuid>"""
import base64, hashlib, hmac, json, sys, time

def b64(raw): return base64.urlsafe_b64encode(raw).rstrip(b"=")
secret, sub = sys.argv[1].encode(), sys.argv[2]
header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
payload = b64(json.dumps({"role": "authenticated", "aud": "authenticated", "sub": sub,
                          "exp": int(time.time()) + 3600}, separators=(",", ":")).encode())
signature = b64(hmac.new(secret, header + b"." + payload, hashlib.sha256).digest())
print((header + b"." + payload + b"." + signature).decode())
