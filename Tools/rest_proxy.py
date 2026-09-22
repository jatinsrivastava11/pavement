#!/usr/bin/env python3
"""Tiny proxy so the Supabase client library can talk to a plain PostgREST.

The library calls `<url>/rest/v1/...`; PostgREST serves those paths at its root. This strips the
prefix and forwards everything else unchanged. Test-only.

  python3 Tools/rest_proxy.py <listen-port> <postgrest-port>
"""
import sys, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN, TARGET = int(sys.argv[1]), int(sys.argv[2])
HOP = {"host", "content-length", "connection", "transfer-encoding"}

class Proxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def forward(self):
        path = self.path[len("/rest/v1"):] if self.path.startswith("/rest/v1") else self.path
        body = self.rfile.read(int(self.headers.get("content-length", 0) or 0)) or None
        req = urllib.request.Request(f"http://127.0.0.1:{TARGET}{path}", data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in HOP:
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req) as resp:
                data, status, headers = resp.read(), resp.status, resp.headers
        except urllib.error.HTTPError as e:
            data, status, headers = e.read(), e.code, e.headers
        except Exception as e:                      # connection refused, etc.
            data, status, headers = str(e).encode(), 502, {}
        self.send_response(status)
        for k, v in (headers.items() if headers else []):
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PATCH = do_DELETE = do_PUT = do_HEAD = forward
    def log_message(self, *args): pass

ThreadingHTTPServer(("127.0.0.1", LISTEN), Proxy).serve_forever()
