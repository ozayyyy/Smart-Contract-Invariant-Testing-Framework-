// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockToken} from "../src/MockToken.sol";
import {Vault} from "../src/Vault.sol";

/// @notice Echidna harness for the correct vault.
/// Echidna calls the public functions with arbitrary inputs and
/// checks the echidna_* properties after every call. Amounts are
/// bounded by modulo so calls rarely revert for trivial reasons.
/// Ghost accounting mirrors the Foundry handler: deposits minus
/// withdrawals, plus yield, plus fees.
/// @dev Run: echidna . --contract EchidnaVault --config echidna.yaml
/// Echidna is a second fuzzing backend for the same properties; it
/// was run locally, see docs/EVALUATION.md for the result.
contract EchidnaVault {
    MockToken public token;
    Vault public vault;

    uint256 public ghostDeposits;
    uint256 public ghostWithdrawals;
    uint256 public ghostYield;
    uint256 public ghostFees;

    constructor() {
        token = new MockToken();
        vault = new Vault(address(token), address(this));
        token.mint(address(this), 1_000_000 ether);
        token.approve(address(vault), type(uint256).max);
    }

    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (x % (max - min + 1));
    }

    function deposit(uint256 amount) public {
        uint256 a = _bound(amount, 1 ether, 50 ether);
        uint256 before = vault.totalAssets();
        uint256 sharesBefore = vault.totalShares();
        uint256 minted = sharesBefore == 0 ? a : (a * sharesBefore) / before;
        if (minted == 0) return;
        try vault.deposit(a) returns (uint256) {
            ghostDeposits += a;
        } catch {}
    }

    function withdraw(uint256 shares) public {
        uint256 held = vault.sharesOf(address(this));
        if (held == 0) return;
        uint256 s = _bound(shares, 1, held);
        uint256 assetsOut = (s * vault.totalAssets()) / vault.totalShares();
        if (assetsOut > token.balanceOf(address(vault))) return;
        if (vault.debtOf(address(this)) > 0) return;
        try vault.withdraw(s) returns (uint256 out) {
            ghostWithdrawals += out;
        } catch {}
    }

    function borrow(uint256 amount) public {
        uint256 headroom = vault.maxBorrow(address(this));
        uint256 owed = vault.debtOf(address(this));
        if (owed >= headroom) return;
        uint256 a = _bound(amount, 1 ether, headroom - owed);
        uint256 fee = a / 100;
        try vault.borrow(a) {
            ghostFees += fee;
        } catch {}
    }

    function repay(uint256 amount) public {
        uint256 owed = vault.debtOf(address(this));
        if (owed == 0) return;
        uint256 a = _bound(amount, 1, owed);
        try vault.repay(a) {} catch {}
    }

    function yield_(uint256 amount) public {
        uint256 a = _bound(amount, 1 ether, 20 ether);
        if (token.balanceOf(address(this)) < a) return;
        try vault.accrueYield(a) {
            ghostYield += a;
        } catch {}
    }

    function setPrice(uint256 factor) public {
        uint256 next = (1e18 * _bound(factor, 80, 100)) / 100;
        try vault.updatePrice(next) {} catch {}
    }

    function echidna_conservation() public view returns (bool) {
        uint256 expected = ghostDeposits + ghostYield + ghostFees;
        if (expected < ghostWithdrawals) return false;
        expected -= ghostWithdrawals;
        uint256 actual = vault.totalAssets();
        return actual >= expected ? actual - expected <= 100 : expected - actual <= 100;
    }

    function echidna_solvency() public view returns (bool) {
        return vault.debtOf(address(this)) <= vault.collateralValue(address(this)) + 1 ether;
    }

    function echidna_feeAccounting() public view returns (bool) {
        return vault.totalFees() == ghostFees;
    }

    function echidna_shareSupply() public view returns (bool) {
        return vault.sharesOf(address(this)) <= vault.totalShares();
    }
}
