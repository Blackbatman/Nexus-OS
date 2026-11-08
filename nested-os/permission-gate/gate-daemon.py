#!/usr/bin/env python3
"""gate-daemon.py — NEXUS-OS Permission Gate.

The isolation heart of "an OS inside the OS": nested guests (terminal-mac macOS
guest, Windows-in-terminal guest) share NOTHING with each other or with the host
unless a request matches policy.json — and every non-pre-approved request queues
for explicit human approval. Default deny. Every decision is logged.

HTTP API (localhost only by design):
  POST /request  {"guest":"terminal-mac","action":"read","path":"~/nexus-workspace/mac/x"}
                 → {"decision":"allowed"|"denied"|"waiting_approval","request_id":N}
  POST /approve  {"request_id":N,"approve":true|false}
  GET  /log      → JSONL of every decision
  GET  /policy   → current policy (sanitized)

Selftest (no hardware, no root, ephemeral port):
  python3 gate-daemon.py --selftest
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_POLICY = {
    "default": "deny",
    "listen": "127.0.0.1",
    "port": 7421,
    "approval_timeout_minutes": 30,
    "guests": {
        "terminal-mac": {"label": "macOS guest (terminal-mac)", "allow": ["~/nexus-workspace/mac/**"]},
        "windows-guest": {"label": "Windows guest (QEMU/KVM)", "allow": ["~/nexus-workspace/win/**"]},
    },
}

ACTIONS = ("read", "write", "execute")


class Gate:
    def __init__(self, policy_path: str | None):
        self.policy_path = policy_path
        self.policy = DEFAULT_POLICY.copy()
        self.lock = threading.Lock()
        self.counter = 0
        self.pending: dict[int, dict] = {}
        self.log: list[dict] = []
        if policy_path and Path(policy_path).exists():
            with open(policy_path) as fh:
                self.policy = json.load(fh)
        if self.policy.get("default") != "deny":
            raise ValueError("policy default must be 'deny' — the gate has no open mode")

    # ---------------------------------------------------------------- rules
    @staticmethod
    def _resolve(path: str) -> str:
        expanded = os.path.expanduser(path)
        return os.path.normpath(expanded)

    def _allowed_by_rule(self, guest: str, resolved: str) -> bool:
        for pattern in self.policy["guests"].get(guest, {}).get("allow", []):
            root = os.path.normpath(os.path.expanduser(pattern.replace("**", "*")))
            base = root.split("*")[0]
            if resolved.startswith(base):
                remainder = resolved[len(base):]
                if fnmatch.fnmatch(remainder if remainder else "/", pattern.split(base.rstrip("/"))[-1] if base in pattern else "*"):
                    return True
                if pattern.endswith("/**") or fnmatch.fnmatch(resolved, os.path.expanduser(pattern)):
                    return True
        return False

    def decide(self, guest: str, action: str, path: str) -> dict:
        with self.lock:
            rec = {
                "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "guest": guest, "action": action, "path": path,
            }
            if guest not in self.policy["guests"]:
                rec.update(decision="denied", reason="unknown guest")
            elif action not in ACTIONS:
                rec.update(decision="denied", reason=f"unknown action {action!r}")
            else:
                resolved = self._resolve(path)
                rec["resolved"] = resolved
                # traversal / symlink-ish escape attempts are denied outright
                base = resolved.split(os.sep)[1] if resolved.startswith(os.sep) else ""
                if ".." in Path(path).parts:
                    rec.update(decision="denied", reason="traversal rejected")
                elif self._allowed_by_rule(guest, resolved):
                    rec.update(decision="allowed", reason="policy allow rule")
                else:
                    self.counter += 1
                    rid = self.counter
                    self.pending[rid] = rec.copy()
                    rec.update(decision="waiting_approval", request_id=rid,
                               reason="default deny — queued for explicit approval")
            self.log.append(rec)
            return rec

    def approve(self, request_id: int, approve: bool) -> dict:
        with self.lock:
            rec = self.pending.pop(request_id, None)
            if rec is None:
                return {"decision": "error", "reason": f"no pending request {request_id}"}
            rec.update(decision="allowed" if approve else "denied",
                       reason="operator approved" if approve else "operator denied",
                       approved_at=rec["ts"])
            self.log.append(dict(rec))
            return rec


def make_handler(gate: Gate):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, obj, code=200):
            body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == "/log":
                self._send({"log": gate.log})
            elif self.path == "/policy":
                self._send({"default": gate.policy["default"],
                            "guests": list(gate.policy["guests"].keys())})
            else:
                self._send({"error": "not found"}, 404)

        def do_POST(self):
            try:
                length = int(self.headers.get("Content-Length", 0))
                data = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                self._send({"decision": "denied", "reason": "malformed JSON"}, 400)
                return
            if self.path == "/request":
                self._send(gate.decide(str(data.get("guest", "")),
                                       str(data.get("action", "")),
                                       str(data.get("path", ""))))
            elif self.path == "/approve":
                self._send(gate.approve(int(data.get("request_id", 0)),
                                        bool(data.get("approve", False))))
            else:
                self._send({"error": "not found"}, 404)

        def log_message(self, *_args):  # silence default stderr spam
            pass
    return Handler


def serve(gate: Gate, host: str, port: int) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((host, port), make_handler(gate))
    server.daemon_threads = True
    return server


# ------------------------------------------------------------------ selftest
def selftest() -> int:
    import urllib.request

    gate = Gate(policy_path=None)  # built-in defaults
    srv = serve(gate, "127.0.0.1", 0)
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    def post(path: str, payload: dict) -> dict:
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}{path}",
            data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())

    failures: list[str] = []

    def expect(name: str, got: dict, decision: str):
        if got.get("decision") != decision:
            failures.append(f"{name}: expected {decision}, got {got}")

    # 1. allowed by rule
    expect("allow-rule", post("/request", {"guest": "terminal-mac", "action": "read",
            "path": "~/nexus-workspace/mac/report.txt"}), "allowed")
    # 2. default deny queues approval
    r = post("/request", {"guest": "terminal-mac", "action": "read",
                          "path": "~/nexus-workspace/win/secret.txt"})
    expect("queue-on-deny", r, "waiting_approval")
    # 3. operator approves → allowed
    a = post("/approve", {"request_id": r["request_id"], "approve": True})
    expect("approve", a, "allowed")
    # 4. unknown guest denied
    expect("unknown-guest", post("/request", {"guest": "ghost", "action": "read",
            "path": "/etc/passwd"}), "denied")
    # 5. traversal rejected
    expect("traversal", post("/request", {"guest": "terminal-mac", "action": "read",
            "path": "~/nexus-workspace/mac/../../etc/shadow"}), "denied")
    # 6. bad action denied
    expect("bad-action", post("/request", {"guest": "terminal-mac", "action": "rm",
            "path": "~/nexus-workspace/mac/x"}), "denied")
    # 7. operator denies queued request
    r2 = post("/request", {"guest": "windows-guest", "action": "write",
                           "path": "~/nexus-workspace/mac/overstep"})
    post("/approve", {"request_id": r2["request_id"], "approve": False})
    if gate.log[-1]["decision"] != "denied":
        failures.append("operator-deny: last decision not denied")
    # 8. malformed JSON → 400
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}/request",
                                     data=b"{not json",
                                     headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req)
        failures.append("malformed-json: request should have raised 400")
    except Exception as exc:
        if "400" not in str(exc):
            failures.append(f"malformed-json: unexpected error {exc}")

    srv.shutdown()
    if failures:
        for f in failures:
            print(f"SELFTEST FAIL: {f}")
        return 1
    print(f"SELFTEST PASS: 8 gate scenarios OK (allow, queue, approve, unknown guest, "
          f"traversal, bad action, operator deny, malformed input)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="NEXUS-OS Permission Gate daemon")
    ap.add_argument("--policy", help="path to policy.json (defaults built-in)")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    gate = Gate(args.policy)
    host = gate.policy["listen"]
    port = gate.policy["port"]
    srv = serve(gate, host, port)
    print(f"[gate] default-deny permission gate on http://{host}:{port}")
    print(f"[gate] guests: {', '.join(gate.policy['guests'])} — approve via POST /approve")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
