# Smart Contract Invariant Testing Framework

A reusable framework for stateful fuzzing of smart contracts: define
invariants, drive sequences of operations through a handler with
multiple actors, and get reproducible, minimised counterexamples when
a property breaks.

## What it does

- Invariant templates (`src/invariants/`) — seven reusable properties:
  conservation, share-to-asset consistency, solvency, supply/balance
  consistency, permissions, debt accounting, fee accounting.
- Stateful handler (`src/harness/Handler.sol`) — drives deposit,
  withdraw, transfer, borrow, repay, liquidate, yield and price
  moves with four actors and configurable roles, and tracks ghost
  accounting: the values the protocol *should* have, computed
  independently from the vault's state before each call.
- Example protocol (`src/Vault.sol`) — a deposit / borrow / liquidate
  vault with proportional shares, a 75% borrowing limit, a 1%
  origination fee, and liquidation at a 10% discount. Plus three
  seeded-defect variants (`src/defects/`), each breaking exactly one
  behaviour.
- Second example protocol (`src/AMM.sol`) — a constant-product AMM
  with LP shares, a 0.3% swap fee kept in the reserves, and a
  minimum liquidity of 1000 locked forever on the first add. Its own
  handler (`src/harness/AmmHandler.sol`), six invariant templates
  (`src/invariants/AmmInvariantTemplates.sol`), and three
  seeded-defect variants, mirroring the vault's structure. Adding it
  is what proves the framework generalises instead of being a
  one-vault demo.
- Foundry invariant tests (`test/`) and Echidna integration
  (`test/EchidnaVault.sol`, `echidna.yaml`, vault only).
- Python runner (`scripts/run.py`) — runs every suite with a fixed
  seed and writes a machine-readable summary to
  `examples/summary.json`.

## Setup

```bash
forge install   # installs forge-std into lib/
forge build
forge test
```

Requires Foundry 1.8.3. Echidna 2.4.0 is optional; install it from
the Crytic release binaries and `pip install crytic-compile`.

Note: a plain `forge test` run is expected to show the six defect
suites failing — that is the point of the seeded defects. The
correct vault, correct AMM, unit tests and regression tests all pass.


## Usage

```bash
# All suites, fixed seed, summary in examples/summary.json
python3 scripts/run.py --seed 1

# Correct vault only
forge test --match-contract InvariantVaultTest

# Correct AMM only
forge test --match-contract InvariantAmmTest

# One defect suite
forge test --match-contract InvariantFeeTest --fuzz-seed 1
forge test --match-contract InvariantAmmNoFeeTest --fuzz-seed 1

# Unit and regression tests only
forge test --match-contract "VaultTest|RegressionTest"
forge test --match-contract "AmmTest|RegressionAmmTest"

# Echidna (second fuzzing backend, same properties, single actor)
echidna test/EchidnaVault.sol --contract EchidnaVault --config echidna.yaml
```

## Adding a protocol

1. Implement the protocol against an interface like `IVault`.
2. Write a handler that drives its operations with several actors
   and tracks ghost accounting for the properties you care about.
   Record ghost values *before* each call, and only update them
   when the call succeeds.
3. Express each property as a function in `src/invariants/` that
   compares actual state with ghost state, with a stated tolerance.
4. Add a test contract that deploys the protocol and handler,
   targets the handler, and asserts one template per
   `invariant_*` function.
5. Add a seeded-defect variant and a regression test from its
   shrunk counterexample (see `test/regression/`).

## How the example protocols work

`Vault` holds an ERC20 asset. Depositors receive shares proportional
to `totalAssets / totalShares`. Borrowers post shares as collateral
and may borrow up to 75% of their collateral value. Borrowing adds
a 1% fee to the debt, so fees accrue to the vault. `accrueYield`
donates asset to the vault and raises the share price.
`updatePrice` moves a collateral price factor (80%–100% of par in
fuzzing), modelling a market move that can make a position
liquidatable. Liquidation repays part of a borrower's debt and
seizes collateral worth the repaid amount plus a 10% bonus, capped
at what the collateral covers. Collateral cannot be withdrawn or
transferred while the owner is in debt beyond the borrowing limit.

`AMM` holds two ERC20 assets as a constant-product pool. The first
liquidity provider mints `sqrt(amountA * amountB)` LP minus a
minimum liquidity of 1000, which is locked in the pool forever, so
the pool can never be fully drained of LP. Later providers mint
the smaller of the two proportional amounts, so an imbalanced add
is priced by the scarcer side. Swaps charge a 0.3% fee that stays
in the reserves and grows the product of the reserves. Removing
liquidity burns LP and pays the proportional share of both
reserves. `getAmountOut` and `getLiquidityOut` expose the pricing
formulas, so the handler can compute the ghost values from the
pool's state before each call.

## Limitations

- A passing invariant campaign does not prove the protocol correct.
  It only shows no sequence in that campaign broke a stated
  invariant, at the configured runs and depth.
- The handler's actors are four funded accounts; it does not model
  MEV, oracle manipulation beyond the price factor, or cross-contract
  interactions. The AMM handler likewise covers four actors and the
  operations listed above; it does not model MEV, sandwiching, or
  flash loans.
- Tolerances are a few wei and cover integer-division rounding only.
- The seeded defects are in the example protocols only. The framework
  itself has no known defects, which is not the same as having none.

## Layout

```
src/               Vault, AMM, MockToken, interfaces
src/defects/       seeded-defect variants (vault D1–D3, AMM D-A1–D-A3)
src/harness/       stateful handlers with ghost accounting
src/invariants/    reusable invariant templates
test/              Foundry invariant suites, unit tests, Echidna harness
test/regression/   regression tests from shrunk counterexamples
scripts/           Python runner (fixed seeds, JSON summary)
docs/              invariant definitions and evaluation
examples/          machine-readable summary of the latest run
SKILL.md           skill file for using this framework with an agent
```

## **Note:** This repository was originally a private project and has been made public for portfolio and educational purposes. Feel free to explore, use, and adapt the code.
