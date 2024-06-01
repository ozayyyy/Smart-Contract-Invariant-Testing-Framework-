# Evaluation

Measured on the example vault only, with Foundry 1.8.3 and Echidna
2.4.0, on the local machine. Reproduce with:

```bash
forge test
python3 scripts/run.py --seed 1
echidna test/EchidnaVault.sol --contract EchidnaVault --config echidna.yaml
```

The canonical run is `examples/summary.json`, produced by
`scripts/run.py --seed 1`. Invariant campaigns use 200 runs and
depth 30 (see `foundry.toml`).

## Foundry invariant suites (fuzz seed 1)

| Suite | Result | Wall | Runs / calls | Broken templates | Counterexample (original → shrunk) |
| --- | --- | --- | --- | --- | --- |
| Correct vault | pass, 7/7 invariants hold | 7.6 s | 200 / 6000 | — | — |
| D1 rounding | fail | 11.2 s | 200 / 6000 | shareAccounting, solvency | 21 → 3 calls (shareAccounting), 21 → 6 (solvency) |
| D2 liquidation | fail | 13.3 s | 200 / 6000 | conservation, debtAccounting, shareAccounting, solvency | 19 → 4 calls |
| D3 fee | fail | 6.3 s | 200 / 6000 | conservation, debtAccounting, feeAccounting | 13 → 2 calls |

The shrunk counterexamples are short enough to read:

- **D1** (3 calls): deposit, borrow, deposit. The second deposit
  mints 1:1 shares after the share price has risen.
- **D2** (4 calls): deposit, borrow near the limit, price fall,
  liquidate.
- **D3** (2 calls): deposit, borrow.

The original (unshrunk) lengths vary a little between runs at the
same seed; the shrunk lengths above are the stable figures, and the
failing templates are the same in every run observed. The
regression tests in `test/regression/` replay the recorded shrunk
sequences exactly and pass on the correct vault.

## Other test results

| Suite | Result |
| --- | --- |
| Unit tests (`VaultTest`) | 7 passed, 0 failed |
| Regression tests (`RegressionTest`) | 6 passed, 0 failed |
| Correct vault, 5 consecutive random-seed runs | 5 passed, 0 failed |

## Echidna (second backend, correct vault)

Echidna 2.4.0, single-actor harness (`test/EchidnaVault.sol`),
20,000 calls, seed 4304958878960147682, about 35 s:

| Property | Result |
| --- | --- |
| conservation | passing |
| solvency | passing |
| feeAccounting | passing |
| shareSupply | passing |

## Issues found by the suite during development

The invariant campaign found three real problems in the example
protocol and harness while it was being built, all fixed before
this evaluation:

1. **Withdraw solvency check ordering.** The check ran after the
   shares were burned but before the assets were transferred, so
   it read the pre-withdraw total assets against the post-withdraw
   share count and inflated the share price. A borrower could
   withdraw collateral and end up with debt above collateral
   value. Fixed by checking after the transfer (a revert still
   rolls the whole call back).
2. **Liquidation over-repayment.** Liquidation capped the seized
   shares at the borrower's balance but not the repaid amount, so
   it could repay more debt than the collateral covered and leave
   debt with zero collateral. Fixed by capping the repaid amount
   to what the collateral covers.
3. **Liquidation unreachable in fuzzing.** Borrow amounts were
   capped at 20 ether while deposits accumulated, so debt never
   approached the 75% threshold and no liquidation ever happened.
   Fixed by borrowing up to the available headroom.

## What this does and does not show

- The three seeded defects are all caught, and the correct vault
  holds all seven templates over 6,000 calls per campaign.
- Discovery of D2 is seed-dependent with random seeds: it was
  found in some random-seed campaigns and not in others. With the
  fixed seed 1 it reproduces on every run observed. A defect that
  needs a specific three-step setup (borrow near the limit, price
  fall, liquidate) is inherently harder to hit by chance than a
  defect triggered by two calls.
- A passing campaign does not prove the protocol correct. It shows
  no sequence in that campaign broke a stated invariant. The
  handler covers four actors and the operations listed in the
  README; it does not model MEV, oracle manipulation beyond the
  price factor, or cross-contract interactions.
- No comparison against other invariant-testing tools was run.
- Echidna's harness is single-actor, so it exercises fewer
  interactions than the Foundry handler (no multi-actor transfers
  or liquidations between actors).
