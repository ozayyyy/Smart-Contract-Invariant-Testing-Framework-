// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockToken} from "../src/MockToken.sol";
import {Vault} from "../src/Vault.sol";
import {Handler} from "../src/harness/Handler.sol";
import {InvariantTemplates} from "../src/invariants/InvariantTemplates.sol";
import {VaultRounding} from "../src/defects/VaultRounding.sol";
import {VaultLiquidation} from "../src/defects/VaultLiquidation.sol";
import {VaultFee} from "../src/defects/VaultFee.sol";

/// @notice One invariant suite per seeded defect. Each suite is
/// expected to FAIL: the defect breaks at least one template. The
/// failing template, seed and sequence are recorded in
/// docs/EVALUATION.md and turned into regression tests in
/// test/regression/.

contract InvariantRoundingTest is StdInvariant, Test {
    MockToken internal token;
    VaultRounding internal vault;
    Handler internal handler;
    address[4] internal actors;

    function setUp() public {
        token = new MockToken();
        vault = new VaultRounding(address(token), address(this));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            token.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            token.approve(address(vault), type(uint256).max);
        }
        handler = new Handler(address(token), address(vault), address(this), actors);
        targetContract(address(handler));
    }

    function invariant_conservation() public view {
        assert(InvariantTemplates.conservation(vault, handler));
    }

    function invariant_shareAccounting() public view {
        assert(InvariantTemplates.shareAccounting(vault, handler));
    }

    function invariant_solvency() public view {
        assert(InvariantTemplates.solvency(vault, handler));
    }

    function invariant_supplyBalance() public view {
        assert(InvariantTemplates.supplyBalance(vault, handler));
    }

    function invariant_permissions() public view {
        assert(InvariantTemplates.permissions(vault));
    }

    function invariant_debtAccounting() public view {
        assert(InvariantTemplates.debtAccounting(vault, handler));
    }

    function invariant_feeAccounting() public view {
        assert(InvariantTemplates.feeAccounting(vault, handler));
    }
}

contract InvariantLiquidationTest is StdInvariant, Test {
    MockToken internal token;
    VaultLiquidation internal vault;
    Handler internal handler;
    address[4] internal actors;

    function setUp() public {
        token = new MockToken();
        vault = new VaultLiquidation(address(token), address(this));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            token.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            token.approve(address(vault), type(uint256).max);
        }
        handler = new Handler(address(token), address(vault), address(this), actors);
        targetContract(address(handler));
    }

    function invariant_conservation() public view {
        assert(InvariantTemplates.conservation(vault, handler));
    }

    function invariant_shareAccounting() public view {
        assert(InvariantTemplates.shareAccounting(vault, handler));
    }

    function invariant_solvency() public view {
        assert(InvariantTemplates.solvency(vault, handler));
    }

    function invariant_supplyBalance() public view {
        assert(InvariantTemplates.supplyBalance(vault, handler));
    }

    function invariant_permissions() public view {
        assert(InvariantTemplates.permissions(vault));
    }

    function invariant_debtAccounting() public view {
        assert(InvariantTemplates.debtAccounting(vault, handler));
    }

    function invariant_feeAccounting() public view {
        assert(InvariantTemplates.feeAccounting(vault, handler));
    }
}

contract InvariantFeeTest is StdInvariant, Test {
    MockToken internal token;
    VaultFee internal vault;
    Handler internal handler;
    address[4] internal actors;

    function setUp() public {
        token = new MockToken();
        vault = new VaultFee(address(token), address(this));
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            token.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            token.approve(address(vault), type(uint256).max);
        }
        handler = new Handler(address(token), address(vault), address(this), actors);
        targetContract(address(handler));
    }

    function invariant_conservation() public view {
        assert(InvariantTemplates.conservation(vault, handler));
    }

    function invariant_shareAccounting() public view {
        assert(InvariantTemplates.shareAccounting(vault, handler));
    }

    function invariant_solvency() public view {
        assert(InvariantTemplates.solvency(vault, handler));
    }

    function invariant_supplyBalance() public view {
        assert(InvariantTemplates.supplyBalance(vault, handler));
    }

    function invariant_permissions() public view {
        assert(InvariantTemplates.permissions(vault));
    }

    function invariant_debtAccounting() public view {
        assert(InvariantTemplates.debtAccounting(vault, handler));
    }

    function invariant_feeAccounting() public view {
        assert(InvariantTemplates.feeAccounting(vault, handler));
    }
}
