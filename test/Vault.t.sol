// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../src/MockToken.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    MockToken internal token;
    Vault internal vault;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        token = new MockToken();
        vault = new Vault(address(token), address(this));
        token.mint(alice, 10_000 ether);
        token.mint(bob, 10_000 ether);
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
    }

    function test_depositWithdrawMath() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100 ether);
        assertEq(shares, 100 ether);
        assertEq(vault.totalAssets(), 100 ether);
        // Yield doubles the share price.
        token.mint(address(this), 100 ether);
        token.approve(address(vault), 100 ether);
        vault.accrueYield(100 ether);
        assertEq(vault.sharePrice(), 2 ether);
        vm.prank(alice);
        uint256 out = vault.withdraw(50 ether);
        assertEq(out, 100 ether);
        assertEq(vault.sharesOf(alice), 50 ether);
    }

    function test_depositAfterYieldMintsProportionally() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        token.mint(address(this), 100 ether);
        token.approve(address(vault), 100 ether);
        vault.accrueYield(100 ether);
        vm.prank(bob);
        uint256 shares = vault.deposit(100 ether);
        // 100 ether at a share price of 2 is 50 shares.
        assertEq(shares, 50 ether);
    }

    function test_borrowLimitEnforced() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vm.expectRevert("exceeds max borrow");
        vault.borrow(80 ether);
    }

    function test_borrowRepayAndFee() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.borrow(50 ether);
        // 50 ether borrowed plus a 1% fee.
        assertEq(vault.debtOf(alice), 505 ether / 10);
        assertEq(vault.totalFees(), 5 ether / 10);
        vm.prank(alice);
        vault.repay(505 ether / 10);
        assertEq(vault.debtOf(alice), 0);
    }

    function test_liquidateOnlyWhenUnhealthy() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.borrow(50 ether);
        vm.prank(bob);
        vm.expectRevert("borrower is healthy");
        vault.liquidate(alice, 10 ether);
    }

    function test_setFeeOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("only owner");
        vault.setFee(200);
        vault.setFee(200);
        assertEq(vault.feeBps(), 200);
    }

    function test_liquidationSeizesProportionally() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.borrow(70 ether);
        // A price fall to 50% halves the collateral value, so the
        // position is liquidatable (70 debt > 37.5 max borrow).
        vault.updatePrice(5e17);
        assertGt(vault.debtOf(alice), vault.maxBorrow(alice));
        vm.prank(bob);
        vault.liquidate(alice, 10 ether);
        assertLt(vault.debtOf(alice), 707 ether / 10);
        assertLt(vault.sharesOf(alice), 100 ether);
    }
}
