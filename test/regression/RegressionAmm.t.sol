// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../../src/MockToken.sol";
import {AMM} from "../../src/AMM.sol";
import {IAMM} from "../../src/IAMM.sol";
import {AmmHandler} from "../../src/harness/AmmHandler.sol";
import {AmmInvariantTemplates} from "../../src/invariants/AmmInvariantTemplates.sol";
import {AmmNoFee} from "../../src/defects/AmmNoFee.sol";
import {AmmLiquidity} from "../../src/defects/AmmLiquidity.sol";
import {AmmRemoval} from "../../src/defects/AmmRemoval.sol";

/// @notice Regression tests generated from real invariant failures.
/// Each sequence is the shrunk counterexample found by the Foundry
/// invariant fuzzer with fuzz seed 1 (see docs/EVALUATION.md for the
/// seeds and lengths). The sequence is replayed against the defective
/// pool, where the stated invariant must still be broken, and
/// against the correct pool, where every invariant must hold. If a
/// defect is ever reintroduced, the "correct holds" test fails; if a
/// defect is ever fixed in its variant, the "defect breaks" test fails.
contract RegressionAmmTest is Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AmmHandler internal handler;
    address[4] internal actors;

    function _fundAndHandler(address ammAddr) internal {
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            tokenA.mint(actors[i], 10_000 ether);
            tokenB.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            tokenA.approve(ammAddr, type(uint256).max);
            vm.prank(actors[i]);
            tokenB.approve(ammAddr, type(uint256).max);
        }
        handler = new AmmHandler(address(tokenA), address(tokenB), ammAddr, actors);
    }

    function _assertAllHold(IAMM amm) internal view {
        assertTrue(AmmInvariantTemplates.reserveAccounting(amm, handler));
        assertTrue(AmmInvariantTemplates.lpAccounting(amm, handler));
        assertTrue(AmmInvariantTemplates.swapFairness(amm, handler));
        assertTrue(AmmInvariantTemplates.productGrowth(amm, handler));
        assertTrue(AmmInvariantTemplates.removalProportionality(amm, handler));
        assertTrue(AmmInvariantTemplates.noDrain(amm, handler));
    }

    /// D-A1, shrunk sequence (original 4 calls, shrunk to 2):
    /// add liquidity, swap. The swap pays the fee-free output, so
    /// the reserves fall short of the ghost reserves.
    function _sequenceNoFee() internal {
        handler.addLiquidity(0, 50 ether, 50 ether);
        handler.swap(0, 10 ether, 0);
    }

    function test_regressionNoFee_defectBreaksSwapFairness() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AmmNoFee amm = new AmmNoFee(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceNoFee();
        assertFalse(AmmInvariantTemplates.swapFairness(amm, handler));
    }

    function test_regressionNoFee_correctHolds() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AMM amm = new AMM(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceNoFee();
        _assertAllHold(amm);
    }

    /// D-A2, shrunk sequence (original 2 calls, shrunk to 1):
    /// a single add. The first add mints LP 1:1 with token A
    /// instead of sqrt(amountA * amountB) minus the minimum, so
    /// the recorded LP is 1000 wei above the ghost value.
    function _sequenceLiquidity() internal {
        handler.addLiquidity(0, 50 ether, 50 ether);
    }

    function test_regressionLiquidity_defectBreaksLpAccounting() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AmmLiquidity amm = new AmmLiquidity(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceLiquidity();
        assertFalse(AmmInvariantTemplates.lpAccounting(amm, handler));
    }

    function test_regressionLiquidity_correctHolds() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AMM amm = new AMM(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceLiquidity();
        _assertAllHold(amm);
    }

    /// D-A3, shrunk sequence (original 3 calls, shrunk to 2):
    /// add liquidity, remove part of it. The removal pays the full
    /// share but burns only half the LP, so the recorded LP supply
    /// is larger than the ghost supply.
    function _sequenceRemoval() internal {
        handler.addLiquidity(0, 50 ether, 50 ether);
        handler.removeLiquidity(0, 10 ether);
    }

    function test_regressionRemoval_defectBreaksLpAccounting() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AmmRemoval amm = new AmmRemoval(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceRemoval();
        assertFalse(AmmInvariantTemplates.lpAccounting(amm, handler));
    }

    function test_regressionRemoval_correctHolds() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        AMM amm = new AMM(address(tokenA), address(tokenB));
        _fundAndHandler(address(amm));
        _sequenceRemoval();
        _assertAllHold(amm);
    }
}
