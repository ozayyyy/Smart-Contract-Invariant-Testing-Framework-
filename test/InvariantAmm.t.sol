// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockToken} from "../src/MockToken.sol";
import {AMM} from "../src/AMM.sol";
import {IAMM} from "../src/IAMM.sol";
import {AmmHandler} from "../src/harness/AmmHandler.sol";
import {AmmInvariantTemplates} from "../src/invariants/AmmInvariantTemplates.sol";

/// @notice Invariant suite for the correct AMM. All six templates
/// must hold after every stateful sequence. A passing run does not
/// prove the pool correct — it only shows no sequence in the
/// campaign broke a stated invariant (see README limitations).
contract InvariantAmmTest is StdInvariant, Test {
    MockToken internal tokenA;
    MockToken internal tokenB;
    AMM internal amm;
    AmmHandler internal handler;
    address[4] internal actors;

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();
        amm = new AMM(address(tokenA), address(tokenB));
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
