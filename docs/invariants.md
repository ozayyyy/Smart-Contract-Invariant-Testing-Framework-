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
