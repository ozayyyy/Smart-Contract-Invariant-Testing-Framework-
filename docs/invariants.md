# Invariant templates

Each template is a property in `src/invariants/InvariantTemplates.sol`.
It compares the vault's actual state with the handler's ghost
accounting, which is computed from the vault's state *before* each
call. Tolerances are a few wei and cover integer-division rounding
on ether-scale amounts only.

## INV-1 Conservation of assets

`totalAssets == deposits - withdrawals + yield + fees`

Assumption: every asset movement is a deposit, withdrawal, borrow,
repay, yield donation, or fee. Borrows and repays do not change
total assets (asset out is offset by debt, and vice versa).
Scope: the whole vault. Broken by D3 (borrow under-records debt).

## INV-2 Share-to-asset consistency

Sum of all actors' shares equals `totalShares`, and each actor's
shares equal the ghost shares implied by their deposits,
withdrawals, transfers and liquidations, within 100 wei.

Assumption: shares are minted proportionally to
`amount * totalShares / totalAssets`. Scope: share accounting only.
Broken by D1 (1:1 mint after the share price rises).

## INV-3 Solvency

For every actor with debt: `debt <= collateral value + 1 ether`.

The liquidation threshold is 75% of collateral value, so a position
may be liquidatable while still solvent. Debt above 100% of
collateral value is bad debt: no collateral covers it.
Assumption: the price factor stays in 80%–100% of par during
fuzzing, so a healthy position can become liquidatable but a single
price move cannot make it insolvent. Scope: per-actor solvency.
Broken by D1 (over-minted shares are withdrawn, leaving other
depositors' shares worth less than their debt) and D2 (liquidation
leaves debt with no collateral).

## INV-4 Supply and balance consistency

Sum of shares equals `totalShares`, sum of debts equals
`totalDebt`, and `totalAssets >= vault asset balance`.

Assumption: shares and debt are only created and destroyed through
the vault's own functions. Scope: accounting totals.

## INV-5 Permissions

`feeBps == 100` at all times.

Assumption: the handler only ever attempts `setFee` as a
non-owner, and never as the owner. Scope: the fee parameter only;
other owner actions (price updates) are modelled as oracle moves
and are not covered by this template.

## INV-6 Debt accounting

Each actor's recorded debt equals the ghost debt implied by their
borrows, repays and liquidations, within 1 wei, and the sum of
debts equals `totalDebt`.

Assumption: the origination fee is 1% of the borrowed amount.
Scope: debt bookkeeping. Broken by D2 (debt reduced by half the
repaid amount) and D3 (debt recorded at 95% of the borrowed amount).

## INV-7 Fee accounting

`totalFees == ghost fees` (1% of each borrowed amount).

Assumption: fees are charged on every borrow and never refunded.
Scope: fee bookkeeping. Broken by D3 (no fee recorded).

## Defect map

| Defect | Description | Broken templates |
| --- | --- | --- |
| D1 `VaultRounding` | Deposit mints shares 1:1, ignoring share price | INV-2, INV-3 |
| D2 `VaultLiquidation` | Liquidation seizes all collateral, debt reduced by half the repaid amount | INV-1, INV-2, INV-3, INV-6 |
| D3 `VaultFee` | Borrow records 95% of the amount as debt, no fee | INV-1, INV-6, INV-7 |

# AMM invariant templates

Each template is a property in
`src/invariants/AmmInvariantTemplates.sol`. It compares the pool's
actual state with the handler's ghost accounting, which is computed
from the pool's state *before* each call using the correct formulas
(0.3% swap fee, proportional LP minting). The swap and removal
templates only apply when the last action was that kind; otherwise
they hold by default. Tolerances are a few wei and cover
integer-division rounding on ether-scale amounts only.

## AMM-1 Reserve accounting

Reserves equal the ghost reserves implied by adds, swaps and
removals, within 100 wei.

Assumption: every reserve movement is an add, swap, or removal,
priced by the correct formulas. Scope: the whole pool. Broken by
D-A1 (fee-free swaps pay out more than the ghost expects).

## AMM-2 LP accounting

Summed LP plus the locked minimum (1000) equals `totalSupply`
once initialised, each actor's LP equals the ghost LP implied by
their adds and removals, within 100 wei, and the ghost total
supply equals the recorded total supply.

Assumption: LP is minted by `sqrt(amountA * amountB)` minus the
minimum on the first add, and by the smaller proportional amount
afterwards. Scope: LP bookkeeping. Broken by D-A2 (1:1 mint) and
D-A3 (removal burns only half the LP).

## AMM-3 Swap fairness

When the last action was a swap, the paid output equals the output
the 0.3%-fee formula gives for the pre-swap reserves, within 100 wei.

Assumption: the fee is 997/1000 on the input amount. Scope: the
most recent swap only. Broken by D-A1 (fee-free output is larger
than the formula gives).

## AMM-4 Product growth

When the last action was a swap, the product of the reserves after
the swap is at least the product before it.

Assumption: the fee stays in the pool, so the product grows on
every swap. A fee-free swap keeps the product flat, so this
template alone does not catch a missing fee — AMM-3 does. Scope:
the most recent swap only.

## AMM-5 Removal proportionality

When the last action was a removal, the paid amounts equal the
proportional share of the pre-removal reserves, within 100 wei.

Assumption: removal pays `lp * reserve / totalSupply` for each
token. Scope: the most recent removal only.

## AMM-6 No drain

While LP exists, both reserves are positive, and no actor holds
more LP than the total supply.

Assumption: LP only exists against positive reserves, because the
first add locks minimum liquidity in the pool. Scope: pool
solvency in the narrow sense — the pool cannot be emptied while
claims on it remain.

## AMM defect map

| Defect | Description | Broken templates |
| --- | --- | --- |
| D-A1 `AmmNoFee` | Swap charges no fee | AMM-1, AMM-3 |
| D-A2 `AmmLiquidity` | Add mints LP 1:1 with token A, ignoring ratio and supply | AMM-2 |
| D-A3 `AmmRemoval` | Removal pays the full share but burns only half the LP | AMM-2 |
