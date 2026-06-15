---
name: smart-contract-invariant-testing-framework
description: Stateful invariant fuzzing for Solidity protocols with Foundry; use when testing a vault, AMM, or other stateful contract for broken accounting, permissions, or solvency.
---

# Smart Contract Invariant Testing Framework

A reusable framework for stateful fuzzing of Solidity contracts.
You state properties the protocol must always hold, a handler drives
random sequences of operations through several actors, and the
fuzzer reports a short, reproducible counterexample when a property
breaks.

## When to use it

- Testing a stateful contract (vault, lending pool, AMM, staking,
  governance) where the risk is broken accounting, not a single
  bad input.
- Checking a fix: write the property first, watch it fail on the
  broken code, then watch it pass on the fixed code.
- Learning invariant testing: the repo ships two working example
  protocols (a vault and a constant-product AMM), each with seeded
  defects that the suite catches.

## Setup

Requires Foundry 1.8.3. Echidna 2.4.0 is optional.

```bash
forge install   # installs forge-std into lib/
forge build
forge test
```

## What is in the repo

- `src/Vault.sol` — example deposit / borrow / liquidate vault:
  proportional shares, 75% borrowing limit, 1% origination fee,
  liquidation at a 10% discount.
- `src/AMM.sol` — example constant-product AMM: LP shares, 0.3%
  swap fee kept in the reserves, minimum liquidity of 1000 locked
  forever on the first add.
- `src/defects/` — seeded-defect variants. Vault: D1 rounding
  (deposit mints 1:1), D2 liquidation (bad debt left behind),
  D3 fee (borrow under-records debt). AMM: D-A1 no fee, D-A2
  liquidity mints LP 1:1 with token A, D-A3 removal burns only
  half the LP. Each variant breaks exactly one behaviour.
- `src/harness/Handler.sol`, `src/harness/AmmHandler.sol` —
  stateful drivers. Each acts as four funded actors, bounds its
  amounts, and tracks ghost accounting: the values the protocol
  *should* have, computed from the protocol's state before each
  call. Ghost values are only updated when a call succeeds; a
  revert changes nothing and is not a failure.
- `src/invariants/` — the properties. Vault: INV-1 conservation,
  INV-2 share consistency, INV-3 solvency, INV-4 supply/balance,
  INV-5 permissions, INV-6 debt accounting, INV-7 fee accounting.
  AMM: AMM-1 reserve accounting, AMM-2 LP accounting, AMM-3 swap
  fairness, AMM-4 product growth, AMM-5 removal proportionality,
  AMM-6 no drain. Full definitions: `docs/invariants.md`.
- `test/` — Foundry invariant suites (one per protocol, one per
  defect), unit tests, and an Echidna harness for the vault.
- `test/regression/` — regression tests replaying the shrunk
  counterexamples for every defect, against both the defective
  and the correct protocol.
- `scripts/run.py` — runs every suite with a fixed seed and writes
  a machine-readable summary to `examples/summary.json`.
- `docs/EVALUATION.md` — measured results: which templates each
  defect breaks, wall times, shrunk counterexample lengths.

## Running it

```bash
# Everything, fixed seed, summary in examples/summary.json
python3 scripts/run.py --seed 1

# Correct vault only (7 invariants) / correct AMM only (6 invariants)
forge test --match-contract InvariantVaultTest
forge test --match-contract InvariantAmmTest

# One defect suite (expected to FAIL — that is the point)
forge test --match-contract InvariantFeeTest --fuzz-seed 1
forge test --match-contract InvariantAmmNoFeeTest --fuzz-seed 1

# Unit and regression tests only
forge test --match-contract "VaultTest|RegressionTest"
forge test --match-contract "AmmTest|RegressionAmmTest"

# Echidna, second fuzzing backend, vault only
echidna test/EchidnaVault.sol --contract EchidnaVault --config echidna.yaml
```

A plain `forge test` run shows the six defect suites failing.
That is expected. The correct vault, correct AMM, unit tests and
regression tests all pass.

## How to read the output

- `[PASS] invariant_<name>` — the property held for the whole
  campaign (200 runs, depth 30 by default, see `foundry.toml`).
- `[FAIL] invariant_<name>` followed by `[Sequence] (original: N,
  shrunk: M)` — the property broke. The shrunk sequence is the
  minimal call list that reproduces the break; read it first, it
  is usually 1–4 calls. The full call list with arguments is
  printed above it.
- A passing campaign does not prove the protocol correct. It only
  shows no sequence in that campaign broke a stated invariant, at
  the configured runs and depth. Say that plainly when reporting
  a pass.
- `examples/summary.json` lists every suite, its pass/fail state,
  the failing invariants, and the counterexample lengths. Use it
  as the source of truth for a run, not terminal scrollback.

## Adding a protocol

1. Implement the protocol against an interface like `IVault` /
   `IAMM`. Keep functions virtual so a defect variant can
   override exactly one behaviour.
2. Write a handler that drives its operations with several actors
   and tracks ghost accounting for the properties you care about.
   Record ghost values *before* each call, and only update them
   when the call succeeds.
3. Express each property as a function in `src/invariants/` that
   compares actual state with ghost state, with a stated
   tolerance (a few wei, covering integer-division rounding only).
4. Add a test contract that deploys the protocol and handler,
   targets the handler, and asserts one template per
   `invariant_*` function.
5. Add a seeded-defect variant and a regression test from its
   shrunk counterexample (see `test/regression/`). The regression
   test must fail the stated invariant on the defect and hold
   every invariant on the correct protocol.

## Safety rules

- Local testing only. Every contract here is an example run on a
  local chain. Never point this framework at a live contract, a
  mainnet fork holding real funds, or a real deployment.
- Never send a real transaction and never spend real money on the
  basis of a test result here.
- The seeded defects are teaching examples. Finding one of them
  in a real codebase means the code needs a fix, not that this
  framework has audited it.
- A passing suite is not an audit. Report the runs, depth, seed
  and the exact invariants checked alongside any pass.
- Keep test funds and test tokens inside the local environment.
  The mock token mints freely and must never be treated as a real
  asset.

## Never use it for

- Auditing or signing off on a live protocol as the only check.
- Deploying a contract, moving funds, or operating a real pool
  or vault.
- Testing against a live network, a live price feed, or another
  person's contracts or funds.
- Claiming a protocol is safe because its invariant campaign
  passed.
