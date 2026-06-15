// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockToken} from "../src/MockToken.sol";
import {AMM} from "../src/AMM.sol";
import {AmmHandler} from "../src/harness/AmmHandler.sol";
import {AmmInvariantTemplates} from "../src/invariants/AmmInvariantTemplates.sol";
import {AmmNoFee} from "../src/defects/AmmNoFee.sol";
import {AmmLiquidity} from "../src/defects/AmmLiquidity.sol";
import {AmmRemoval} from "../src/defects/AmmRemoval.sol";

/// @notice One invariant suite per seeded AMM defect. Each suite is
/// expected to FAIL: the defect breaks at least one template. The
/// failing template, seed and sequence are recorded in
/// docs/EVALUATION.md and turned into regression tests in
/// test/regression/.

contract InvariantAmmNoFeeTest is StdInvariant, Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AmmNoFee internal amm;
    AmmHandler internal handler;
    address[4] internal actors;

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        amm = new AmmNoFee(address(tokenA), address(tokenB));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            tokenA.mint(actors[i], 10_000 ether);
            tokenB.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            tokenA.approve(address(amm), type(uint256).max);
            vm.prank(actors[i]);
            tokenB.approve(address(amm), type(uint256).max);
        }
        handler = new AmmHandler(address(tokenA), address(tokenB), address(amm), actors);
        targetContract(address(handler));
    }

    function invariant_reserveAccounting() public view {
        assert(AmmInvariantTemplates.reserveAccounting(amm, handler));
    }

    function invariant_lpAccounting() public view {
        assert(AmmInvariantTemplates.lpAccounting(amm, handler));
    }

    function invariant_swapFairness() public view {
        assert(AmmInvariantTemplates.swapFairness(amm, handler));
    }

    function invariant_productGrowth() public view {
        assert(AmmInvariantTemplates.productGrowth(amm, handler));
    }

    function invariant_removalProportionality() public view {
        assert(AmmInvariantTemplates.removalProportionality(amm, handler));
    }

    function invariant_noDrain() public view {
        assert(AmmInvariantTemplates.noDrain(amm, handler));
    }
}

contract InvariantAmmLiquidityTest is StdInvariant, Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AmmLiquidity internal amm;
    AmmHandler internal handler;
    address[4] internal actors;

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        amm = new AmmLiquidity(address(tokenA), address(tokenB));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            tokenA.mint(actors[i], 10_000 ether);
            tokenB.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            tokenA.approve(address(amm), type(uint256).max);
            vm.prank(actors[i]);
            tokenB.approve(address(amm), type(uint256).max);
        }
        handler = new AmmHandler(address(tokenA), address(tokenB), address(amm), actors);
        targetContract(address(handler));
    }

    function invariant_reserveAccounting() public view {
        assert(AmmInvariantTemplates.reserveAccounting(amm, handler));
    }

    function invariant_lpAccounting() public view {
        assert(AmmInvariantTemplates.lpAccounting(amm, handler));
    }

    function invariant_swapFairness() public view {
        assert(AmmInvariantTemplates.swapFairness(amm, handler));
    }

    function invariant_productGrowth() public view {
        assert(AmmInvariantTemplates.productGrowth(amm, handler));
    }

    function invariant_removalProportionality() public view {
        assert(AmmInvariantTemplates.removalProportionality(amm, handler));
    }

    function invariant_noDrain() public view {
        assert(AmmInvariantTemplates.noDrain(amm, handler));
    }
}

contract InvariantAmmRemovalTest is StdInvariant, Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AmmRemoval internal amm;
    AmmHandler internal handler;
    address[4] internal actors;

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        amm = new AmmRemoval(address(tokenA), address(tokenB));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            tokenA.mint(actors[i], 10_000 ether);
            tokenB.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            tokenA.approve(address(amm), type(uint256).max);
            vm.prank(actors[i]);
            tokenB.approve(address(amm), type(uint256).max);
        }
        handler = new AmmHandler(address(tokenA), address(tokenB), address(amm), actors);
        targetContract(address(handler));
    }

    function invariant_reserveAccounting() public view {
        assert(AmmInvariantTemplates.reserveAccounting(amm, handler));
    }

    function invariant_lpAccounting() public view {
        assert(AmmInvariantTemplates.lpAccounting(amm, handler));
    }

    function invariant_swapFairness() public view {
        assert(AmmInvariantTemplates.swapFairness(amm, handler));
    }

    function invariant_productGrowth() public view {
        assert(AmmInvariantTemplates.productGrowth(amm, handler));
    }

    function invariant_removalProportionality() public view {
        assert(AmmInvariantTemplates.removalProportionality(amm, handler));
    }

    function invariant_noDrain() public view {
        assert(AmmInvariantTemplates.noDrain(amm, handler));
    }
}
