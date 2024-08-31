// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../MockToken.sol";
import {IVault} from "../IVault.sol";

/// @title Handler — stateful driver for invariant testing.
/// @notice The fuzzer calls these functions with arbitrary seeds. Each
/// function acts as one of four actors, bounds its amounts, and records
/// ghost state: the accounting the protocol *should* have, computed
/// from the vault's own state before the call. Invariants compare the
/// vault's actual state against this ghost state. Calls that revert
/// change nothing and are not recorded — a revert is not a failure.
/// @dev The handler inherits Test so it can use vm.prank to act as
/// each actor. It never acts as the vault owner.
contract Handler is Test {
    MockToken public token;
    IVault public vault;
    address public owner;
    address[4] public actors;

    // Ghost accounting (intended values, computed independently).
    mapping(address => uint256) public expectedShares;
    mapping(address => uint256) public expectedDebt;
    uint256 public ghostDeposits;
    uint256 public ghostWithdrawals;
    uint256 public ghostYield;
    uint256 public ghostFees;
    uint256 public ghostCalls;

    mapping(bytes32 => uint256) public callCounts;

    constructor(address _token, address _vault, address _owner, address[4] memory _actors) {
        token = MockToken(_token);
        vault = IVault(_vault);
        owner = _owner;
        actors = _actors;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, 3)];
    }

    function _count(string memory name) internal {
        callCounts[keccak256(bytes(name))]++;
        ghostCalls++;
    }

    function deposit(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 1 ether, 50 ether);
        uint256 totalShares = vault.totalShares();
        uint256 totalAssets = vault.totalAssets();
        uint256 minted = totalShares == 0 ? amount : (amount * totalShares) / totalAssets;
        if (minted == 0) return;
        _count("deposit");
        vm.prank(actor);
        try vault.deposit(amount) {
            ghostDeposits += amount;
            expectedShares[actor] += minted;
        } catch {}
    }

    function withdraw(uint256 actorSeed, uint256 sharesSeed) public {
        address actor = _actor(actorSeed);
        uint256 held = vault.sharesOf(actor);
        if (held == 0) return;
        uint256 sharesAmount = bound(sharesSeed, 1, held);
        uint256 assetsOut = (sharesAmount * vault.totalAssets()) / vault.totalShares();
        if (assetsOut == 0 || assetsOut > token.balanceOf(address(vault))) return;
        _count("withdraw");
        vm.prank(actor);
        try vault.withdraw(sharesAmount) {
            ghostWithdrawals += assetsOut;
            expectedShares[actor] -= sharesAmount;
        } catch {}
    }

    function transferShares(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) public {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;
        uint256 held = vault.sharesOf(from);
        if (held == 0) return;
        uint256 amount = bound(amountSeed, 1, held);
        _count("transferShares");
        vm.prank(from);
        try vault.transferShares(to, amount) {
            expectedShares[from] -= amount;
            expectedShares[to] += amount;
        } catch {}
    }

    function borrow(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _actor(actorSeed);
        // Borrow up to the available headroom (max borrow minus debt,
        // less the fee), so positions regularly sit near the 75%
        // threshold and a price fall can make them liquidatable. A
        // flat 1–20 ether cap never got close to the threshold, which
        // made liquidation unreachable in fuzzing.
        uint256 owed = vault.debtOf(actor);
        if (owed >= vault.maxBorrow(actor)) return;
        uint256 headroom = vault.maxBorrow(actor) - owed;
        if (headroom <= 1 ether) return;
        uint256 maxPrincipal = (headroom * 100) / 101;
        if (maxPrincipal <= 1 ether) return;
        uint256 amount = bound(amountSeed, 1 ether, maxPrincipal);
        uint256 fee = amount / 100;
        if (amount > token.balanceOf(address(vault))) return;
        _count("borrow");
        vm.prank(actor);
        try vault.borrow(amount) {
            expectedDebt[actor] += amount + fee;
            ghostFees += fee;
        } catch {}
    }

    function repay(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _actor(actorSeed);
        uint256 owed = vault.debtOf(actor);
        if (owed == 0) return;
        uint256 amount = bound(amountSeed, 1, owed);
        _count("repay");
        vm.prank(actor);
        try vault.repay(amount) {
            expectedDebt[actor] -= amount;
        } catch {}
    }

    function liquidate(uint256 liquidatorSeed, uint256 borrowerSeed, uint256 amountSeed) public {
        address liquidator = _actor(liquidatorSeed);
        address borrower = _actor(borrowerSeed);
        if (liquidator == borrower) return;
        uint256 owed = vault.debtOf(borrower);
        if (owed == 0) return;
        if (owed <= vault.maxBorrow(borrower)) return;
        uint256 pay = bound(amountSeed, 1 ether, 20 ether);
        if (pay > owed) pay = owed;
        uint256 maxPay = ((vault.sharesOf(borrower) * vault.sharePrice()) / 1e18 * 10000) / 11000;
        if (pay > maxPay) pay = maxPay;
        if (pay == 0) return;
        uint256 price = vault.sharePrice();
        uint256 seized = (pay * 1e18) / price;
        seized = (seized * 11000) / 10000;
        uint256 borrowerShares = vault.sharesOf(borrower);
        if (seized > borrowerShares) seized = borrowerShares;
        _count("liquidate");
        vm.prank(liquidator);
        try vault.liquidate(borrower, pay) {
            expectedDebt[borrower] -= pay;
            expectedShares[borrower] -= seized;
            expectedShares[liquidator] += seized;
        } catch {}
    }

    function accrueYield(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 1 ether, 20 ether);
        if (token.balanceOf(actor) < amount) return;
        _count("accrueYield");
        vm.prank(actor);
        try vault.accrueYield(amount) {
            ghostYield += amount;
        } catch {}
    }

    /// @notice Price update, acting as the owner (the price oracle).
    /// The factor is always 80%–100% of par, never compounded, so a
    /// healthy position can become liquidatable but never instantly
    /// insolvent from price moves alone.
    function updatePrice(uint256 factorSeed) public {
        uint256 next = (1e18 * bound(factorSeed, 80, 100)) / 100;
        _count("updatePrice");
        vm.prank(owner);
        try vault.updatePrice(next) {} catch {}
    }

    /// @notice Attempts an owner-only action as a non-owner. It must
    /// always revert; the fee must never change through this path.
    function setFeeAsNonOwner(uint256 actorSeed, uint256 feeSeed) public {
        address actor = _actor(actorSeed);
        if (actor == owner) return;
        uint256 fee = bound(feeSeed, 0, 1000);
        _count("setFeeAsNonOwner");
        vm.prank(actor);
        try vault.setFee(fee) {} catch {}
    }

    /// @notice Expected total assets from ghost accounting: deposits
    /// minus withdrawals, plus yield, plus fees. Borrows and repays do
    /// not change it (asset out is offset by debt, and vice versa).
    function expectedTotalAssets() public view returns (uint256) {
        return ghostDeposits + ghostYield + ghostFees - ghostWithdrawals;
    }

    function sumShares() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += vault.sharesOf(actors[i]);
    }

    function sumDebt() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += vault.debtOf(actors[i]);
    }

    function sumExpectedShares() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += expectedShares[actors[i]];
    }

    function sumExpectedDebt() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += expectedDebt[actors[i]];
    }
}
