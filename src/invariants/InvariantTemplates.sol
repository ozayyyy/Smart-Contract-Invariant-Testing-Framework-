// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "../IVault.sol";
import {Handler} from "../harness/Handler.sol";

/// @title Invariant templates.
/// @notice Each template is one reusable property with a stated
/// assumption and scope (see docs/invariants.md). They compare the
/// vault's actual state against the handler's ghost accounting, which
/// is computed independently from the vault's state before each call.
/// Tolerances are in wei and cover only integer-division rounding on
/// ether-scale amounts; they are far smaller than any real defect.
/// @dev A property returning false is a broken invariant, not a
/// reverted call. Tests assert each template after every sequence.
library InvariantTemplates {
    uint256 internal constant TOLERANCE = 100;

    function _diff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /// INV-1 conservation of assets: total assets equal deposits
    /// minus withdrawals, plus yield, plus fees.
    function conservation(IVault vault, Handler handler) internal view returns (bool) {
        return _diff(vault.totalAssets(), handler.expectedTotalAssets()) <= TOLERANCE;
    }

    /// INV-2 share-to-asset consistency: shares are proportional to
    /// deposits, and the sum of shares equals total supply.
    function shareAccounting(IVault vault, Handler handler) internal view returns (bool) {
        if (handler.sumShares() != vault.totalShares()) return false;
        for (uint256 i = 0; i < 4; i++) {
            address actor = handler.actors(i);
            if (_diff(vault.sharesOf(actor), handler.expectedShares(actor)) > TOLERANCE) return false;
        }
        return true;
    }

    /// INV-3 solvency: no actor's debt exceeds the value of their
    /// collateral shares. The liquidation threshold is 75%, so a
    /// position may be liquidatable while still solvent; debt above
    /// 100% of collateral is bad debt.
    function solvency(IVault vault, Handler handler) internal view returns (bool) {
        for (uint256 i = 0; i < 4; i++) {
            address actor = handler.actors(i);
            uint256 debt = vault.debtOf(actor);
            if (debt == 0) continue;
            if (debt > vault.collateralValue(actor) + 1 ether) return false;
        }
        return true;
    }

    /// INV-4 supply and balance consistency: summed shares and debts
    /// equal the totals, and total assets are at least the vault balance.
    function supplyBalance(IVault vault, Handler handler) internal view returns (bool) {
        if (handler.sumShares() != vault.totalShares()) return false;
        if (handler.sumDebt() != vault.totalDebt()) return false;
        if (vault.totalAssets() < vaultTotalBalance(vault)) return false;
        return true;
    }

    function vaultTotalBalance(IVault vault) internal view returns (uint256) {
        // totalAssets() is balance + debt, so balance = totalAssets - debt.
        return vault.totalAssets() - vault.totalDebt();
    }

    /// INV-5 permission: the origination fee never changes, because
    /// the handler only ever attempts to set it as a non-owner.
    function permissions(IVault vault) internal view returns (bool) {
        return vault.feeBps() == 100;
    }

    /// INV-6 debt accounting: recorded debt matches the ghost debt
    /// implied by borrows, repays and liquidations.
    function debtAccounting(IVault vault, Handler handler) internal view returns (bool) {
        if (handler.sumDebt() != vault.totalDebt()) return false;
        for (uint256 i = 0; i < 4; i++) {
            address actor = handler.actors(i);
            if (_diff(vault.debtOf(actor), handler.expectedDebt(actor)) > 1) return false;
        }
        return true;
    }

    /// INV-7 fee accounting: recorded fees equal the ghost fees
    /// implied by borrows (1% of each borrowed amount).
    function feeAccounting(IVault vault, Handler handler) internal view returns (bool) {
        return vault.totalFees() == handler.ghostFees();
    }
}
