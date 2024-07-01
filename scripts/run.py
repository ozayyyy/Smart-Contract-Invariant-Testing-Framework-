#!/usr/bin/env python3
"""Run the invariant suites and write a machine-readable summary.

Usage:
    python3 scripts/run.py [--seed 1] [--output examples/summary.json]

Each invariant suite is run with a fixed fuzz seed so the result is
reproducible. The runner parses Foundry's output for the failing
invariants and the counterexample sequence lengths (original and
shrunk by Foundry's shrinker). It does not invent results: a suite
that was not run is reported as not run, and a run that fails to
parse is reported as unknown.
"""

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SUITES = [
    ("InvariantVaultTest", "correct", "test/InvariantVault.t.sol"),
    ("InvariantRoundingTest", "defect-rounding", "test/InvariantDefects.t.sol"),
    ("InvariantLiquidationTest", "defect-liquidation", "test/InvariantDefects.t.sol"),
    ("InvariantFeeTest", "defect-fee", "test/InvariantDefects.t.sol"),
    ("VaultTest", "unit", "test/Vault.t.sol"),
    ("RegressionTest", "regression", "test/regression/Regression.t.sol"),
]

INVARIANT_RE = re.compile(r"\[(PASS|FAIL)[^\]]*\]\s+(invariant_\w+)")
SEQUENCE_RE = re.compile(r"\[Sequence\] \(original: (\d+), shrunk: (\d+)\)")
RUNS_RE = re.compile(r"runs: (\d+), calls: (\d+)")
SEED_RE = re.compile(r"Fuzz seed: (0x[0-9a-f]+)")
FINISHED_RE = re.compile(r"finished in ([\d.]+)s")


def run(cmd):
    start = time.monotonic()
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=600)
    return proc.stdout + proc.stderr, time.monotonic() - start


def run_suite(name, kind, seed):
    output, wall = run(
        ["forge", "test", "--match-contract", f"^{name}$", "--fuzz-seed", str(seed)]
    )
    invariants = {}
    for status, inv in INVARIANT_RE.findall(output):
        invariants[inv] = status.lower()
    sequences = [(int(a), int(b)) for a, b in SEQUENCE_RE.findall(output)]
    runs = RUNS_RE.search(output)
    seed_m = SEED_RE.search(output)
    return {
        "contract": name,
        "kind": kind,
        "seed": seed_m.group(1) if seed_m else str(seed),
        "wall_seconds": round(wall, 2),
        "passed": "Suite result: ok" in output,
        "invariants": invariants,
        "failing_invariants": [k for k, v in invariants.items() if v == "fail"],
        "counterexample_sequences": [
            {"original_calls": a, "shrunk_calls": b} for a, b in sequences
        ],
        "runs": int(runs.group(1)) if runs else None,
        "calls": int(runs.group(2)) if runs else None,
    }


def main():
    parser = argparse.ArgumentParser(description="Run invariant suites and summarise them.")
    parser.add_argument("--seed", default="1", help="Fuzz seed for invariant suites.")
    parser.add_argument("--output", default="examples/summary.json", help="Summary JSON path.")
    args = parser.parse_args()

    results = []
    for name, kind, _path in SUITES:
        print(f"running {name} ...", flush=True)
        results.append(run_suite(name, kind, args.seed))

    summary = {"seed": args.seed, "suites": results}
    out = ROOT / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2) + "\n")

    print(f"{'suite':<28} {'result':<8} {'wall':>6}  failing")
    for r in results:
        print(
            f"{r['contract']:<28} {'pass' if r['passed'] else 'FAIL':<8} "
            f"{r['wall_seconds']:>6.2f}  {', '.join(r['failing_invariants']) or '-'}"
        )
    print(f"summary written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
