// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../src/MockToken.sol";
import {AMM} from "../src/AMM.sol";

contract AmmTest is Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AMM internal amm;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        amm = new AMM(address(tokenA), address(tokenB));
        tokenA.mint(alice, 10_000 ether);
        tokenB.mint(alice, 10_000 ether);
        tokenA.mint(bob, 10_000 ether);
        tokenB.mint(bob, 10_000 ether);
        vm.prank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(alice);
        tokenB.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        tokenB.approve(address(amm), type(uint256).max);
    }

    function test_firstAddMintsSqrtMinusMinimum() public {
        vm.prank(alice);
        uint256 lp = amm.addLiquidity(100 ether, 100 ether);
        // sqrt(100 * 100) ether minus the locked minimum of 1000 wei.
        assertEq(lp, 100 ether - 1000);
        // Total supply counts the locked minimum as well.
        assertEq(amm.totalSupply(), 100 ether);
        assertEq(amm.reserveA(), 100 ether);
        assertEq(amm.reserveB(), 100 ether);
    }

    function test_secondAddMintsProportionally() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(bob);
        uint256 lp = amm.addLiquidity(50 ether, 50 ether);
        assertEq(lp, 50 ether);
        assertEq(amm.reserveA(), 150 ether);
        assertEq(amm.reserveB(), 150 ether);
    }

    function test_imbalancedAddPricedByScarcerSide() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(bob);
        uint256 lp = amm.addLiquidity(50 ether, 100 ether);
        // min(50 * 100 / 100, 100 * 100 / 100) = 50 ether.
        assertEq(lp, 50 ether);
        assertEq(amm.reserveA(), 150 ether);
        assertEq(amm.reserveB(), 200 ether);
    }

    function test_swapChargesFeeAndGrowsProduct() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        uint256 kBefore = amm.reserveA() * amm.reserveB();
        vm.prank(bob);
        uint256 out = amm.swap(10 ether, true);
        assertEq(out, amm.getAmountOut(10 ether, 100 ether, 100 ether));
        // The fee keeps part of the input in the pool, so the trader
        // gets less than the fee-free 10 * 100 / 110 (about 9.09).
        assertLt(out, 91 ether / 10);
        assertGt(amm.reserveA() * amm.reserveB(), kBefore);
    }

    function test_swapBothDirections() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(bob);
        uint256 outB = amm.swap(10 ether, true);
        assertGt(outB, 0);
        vm.prank(bob);
        uint256 outA = amm.swap(10 ether, false);
        assertGt(outA, 0);
    }

    function test_removeLiquidityPaysProportionally() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(alice);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(50 ether);
        assertEq(outA, 50 ether);
        assertEq(outB, 50 ether);
        assertEq(amm.reserveA(), 50 ether);
        assertEq(amm.reserveB(), 50 ether);
    }

    function test_removeAllLpLeavesOnlyMinimumLocked() public {
        vm.prank(alice);
        uint256 lp = amm.addLiquidity(100 ether, 100 ether);
        vm.prank(alice);
        amm.removeLiquidity(lp);
        // The locked minimum's share of the reserves stays behind.
        assertEq(amm.totalSupply(), 1000);
        assertEq(amm.reserveA(), 1000);
        assertEq(amm.reserveB(), 1000);
    }

    function test_addZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert("zero liquidity");
        amm.addLiquidity(0, 100 ether);
    }

    function test_swapZeroReverts() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(bob);
        vm.expectRevert("zero swap");
        amm.swap(0, true);
    }

    function test_removeMoreThanBalanceReverts() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        vm.prank(bob);
        vm.expectRevert("insufficient lp");
        amm.removeLiquidity(1 ether);
    }
}
