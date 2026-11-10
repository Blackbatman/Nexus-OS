#!/usr/bin/env python3
"""statecheck.py — NEXUS-OS explicit state-machine registry validator.

NEXUS-OS discovered twelve implicit state machines scattered across its
components (boot intent contract, gate daemon, voice parser, chain guards,
hub lifecycle, handoff reset, ...). docs/10-state-machines.md tells the human
story; agents/state-machines.json is the machine-readable registry this tool
validates, so agents and CI share one source of truth (the AX contract).

What it enforces per machine:
  R1 schema     — required fields present, types sane
  R2 states     — initial exists; terminals subset; no duplicate states
  R3 edges      — from/to reference declared states; guard and source present
  R4 determinism— no two transitions share (from, guard)
  R5 reachability— every state reachable from initial
  R6 terminals  — at least one terminal; terminals have no outgoing edges
  R7 sources    — every cited file exists in the repo (line numbers advisory)

Usage:
  python3 tools/statecheck/statecheck.py --selftest
  python3 tools/statecheck/statecheck.py agents/state-machines.json [--repo-root PATH]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import deque

REQUIRED_MACHINE_FIELDS = {
    "id": str, "name": str, "component": str,
    "initial": str, "states": list, "terminals": list,
    "transitions": list,
}
REQUIRED_TRANSITION_FIELDS = {"from": str, "guard": str, "to": str, "source": str}


def load_registry(path: str) -> dict:
    with open(path) as fh:
        data = json.load(fh)
    if not isinstance(data, dict) or not isinstance(data.get("machines"), list):
        raise ValueError("registry must be an object with a 'machines' list")
    return data


def check_machine(m: dict, repo_root: str) -> list[str]:
    errs: list[str] = []
    mid = m.get("id", "<missing-id>")
    bad = m.get("id") is None

    # R1 schema
    for field, kind in REQUIRED_MACHINE_FIELDS.items():
        if field not in m:
            errs.append(f"{mid}: missing required field '{field}'")
            bad = True
        elif not isinstance(m[field], kind):
            errs.append(f"{mid}: field '{field}' must be {kind.__name__}")
            bad = True
    if bad:
        return errs

    states = m["states"]
    if len(states) != len(set(states)):
        errs.append(f"{mid}: duplicate state names")
    state_set = set(states)

    # R2 initial / terminals
    if m["initial"] not in state_set:
        errs.append(f"{mid}: initial '{m['initial']}' not declared in states")
    for t in m["terminals"]:
        if t not in state_set:
            errs.append(f"{mid}: terminal '{t}' not declared in states")

    # R3/R4 edges
    seen_pairs: set[tuple[str, str]] = set()
    edges: list[tuple[str, str]] = []
    for i, tr in enumerate(m["transitions"]):
        for field in REQUIRED_TRANSITION_FIELDS:
            if field not in tr:
                errs.append(f"{mid}: transition[{i}] missing '{field}'")
        f, t = tr.get("from", "?"), tr.get("to", "?")
        if f not in state_set:
            errs.append(f"{mid}: transition[{i}] 'from' unknown state {f!r}")
        if t not in state_set:
            errs.append(f"{mid}: transition[{i}] 'to' unknown state {t!r}")
        pair = (f, tr.get("guard", ""))
        if pair in seen_pairs:
            errs.append(f"{mid}: nondeterministic guard {pair[1]!r} from state {f!r}")
        seen_pairs.add(pair)
        edges.append((f, t))
        src = tr.get("source", "")
        path = src.split(":")[0] if src else ""
        if path and not os.path.exists(os.path.join(repo_root, path)):
            errs.append(f"{mid}: transition[{i}] source file missing: {path}")

    # R5 reachability
    adj: dict[str, list[str]] = {s: [] for s in states}
    for f, t in edges:
        if f in adj:
            adj[f].append(t)
    seen: set[str] = set()
    queue = deque([m["initial"]] if m["initial"] in state_set else [])
    while queue:
        node = queue.popleft()
        if node in seen:
            continue
        seen.add(node)
        queue.extend(adj.get(node, []))
    for s in states:
        if s not in seen:
            errs.append(f"{mid}: state {s!r} unreachable from initial")

    # R6 terminals
    if not m["terminals"]:
        errs.append(f"{mid}: no terminal state (every machine needs a halt)")
    terminal_set = set(m["terminals"])
    for f, _t in edges:
        if f in terminal_set:
            errs.append(f"{mid}: terminal {f!r} has an outgoing transition")
    return errs


def validate(data: dict, repo_root: str) -> list[str]:
    errs: list[str] = []
    ids = [m.get("id", "<missing>") for m in data["machines"]]
    if len(ids) != len(set(ids)):
        errs.append("registry: duplicate machine ids")
    for m in data["machines"]:
        errs.extend(check_machine(m, repo_root))
    return errs


# ------------------------------------------------------------------ selftest
GOOD_MACHINE = {
    "id": "T01", "name": "toggle", "component": "selftest",
    "initial": "OFF", "states": ["OFF", "ON"], "terminals": ["ON"],
    "transitions": [{"from": "OFF", "guard": "flip", "to": "ON", "source": "tools/statecheck/statecheck.py"}],
}
BAD_MACHINES = [
    # unreachable state
    {"id": "T02", "name": "broken reach", "component": "selftest",
     "initial": "A", "states": ["A", "B"], "terminals": ["B"],
     "transitions": []},
    # nondeterministic guard
    {"id": "T03", "name": "broken determinism", "component": "selftest",
     "initial": "A", "states": ["A", "B", "C"], "terminals": ["B"],
     "transitions": [
         {"from": "A", "guard": "go", "to": "B", "source": "tools/statecheck/statecheck.py"},
         {"from": "A", "guard": "go", "to": "C", "source": "tools/statecheck/statecheck.py"},
     ]},
    # edge out of a terminal
    {"id": "T04", "name": "broken terminal", "component": "selftest",
     "initial": "A", "states": ["A", "B"], "terminals": ["A"],
     "transitions": [{"from": "A", "guard": "go", "to": "B", "source": "tools/statecheck/statecheck.py"}]},
]


def selftest() -> int:
    import copy
    failures: list[str] = []
    ok = check_machine(copy.deepcopy(GOOD_MACHINE), repo_root=".")
    if ok:
        failures.append(f"good machine rejected: {ok}")
    for bad in BAD_MACHINES:
        problems = check_machine(copy.deepcopy(bad), repo_root=".")
        if not problems:
            failures.append(f"bad machine {bad['id']} accepted")
    if failures:
        for f in failures:
            print(f"SELFTEST FAIL: {f}")
        return 1
    print("SELFTEST PASS: 4 statecheck scenarios OK "
          "(good registry, unreachable state, nondeterministic guard, leaky terminal)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="NEXUS-OS state-machine registry validator")
    ap.add_argument("registry", nargs="?", help="path to state-machines.json")
    ap.add_argument("--repo-root", default=".", help="root used to resolve source refs")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not args.registry:
        ap.print_help()
        return 2
    try:
        data = load_registry(args.registry)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"REGISTRY FAIL: cannot load {args.registry}: {exc}")
        return 1
    errs = validate(data, args.repo_root)
    n_machines = len(data["machines"])
    n_edges = sum(len(m.get("transitions", [])) for m in data["machines"])
    if errs:
        for e in errs:
            print(f"REGISTRY VIOLATION: {e}")
        print(f"REGISTRY FAIL: {n_machines} machines / {n_edges} transitions, "
              f"{len(errs)} violation(s)")
        return 1
    print(f"REGISTRY PASS: {n_machines} machines, {n_edges} transitions, 0 violations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
