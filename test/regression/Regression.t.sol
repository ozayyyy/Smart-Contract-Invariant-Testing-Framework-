// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../../src/MockToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IVault} from "../../src/IVault.sol";
import {Handler} from "../../src/harness/Handler.sol";
import {InvariantTemplates} from "../../src/invariants/InvariantTemplates.sol";
import {VaultRounding} from "../../src/defects/VaultRounding.sol";
import {VaultLiquidation} from "../../src/defects/VaultLiquidation.sol";
import {VaultFee} from "../../src/defects/VaultFee.sol";

/// @notice Regression tests generated from real invariant failures.
/// Each sequence is the shrunk counterexample found by the Foundry
/// invariant fuzzer with fuzz seed 1 (see docs/EVALUATION.md for the
/// seeds and lengths). The sequence is replayed against the defective
/// vault, where the stated invariant must still be broken, and
/// against the correct vault, where every invariant must hold. If a
/// defect is ever reintroduced, the "correct holds" test fails; if a
/// defect is ever fixed in its variant, the "defect breaks" test fails.
contract RegressionTest is Test {
    MockToken internal token;
    Handler internal handler;
    address[4] internal actors;

    function _fundAndHandler(address vaultAddr) internal {
        actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
        for (uint256 i = 0; i < 4; i++) {
            token.mint(actors[i], 10_000 ether);
            vm.prank(actors[i]);
            token.approve(vaultAddr, type(uint256).max);
        }
        handler = new Handler(address(token), vaultAddr, address(this), actors);
    }

    function _assertAllHold(IVault vault) internal view {
        assertTrue(InvariantTemplates.conservation(vault, handler));
        assertTrue(InvariantTemplates.shareAccounting(vault, handler));
        assertTrue(InvariantTemplates.solvency(vault, handler));
        assertTrue(InvariantTemplates.supplyBalance(vault, handler));
        assertTrue(InvariantTemplates.permissions(vault));
        assertTrue(InvariantTemplates.debtAccounting(vault, handler));
        assertTrue(InvariantTemplates.feeAccounting(vault, handler));
    }

    /// D1, shrunk sequence (original 21 calls, shrunk to 3):
    /// deposit, borrow, deposit. The second deposit mints 1:1 shares
    /// after the share price has risen, over-minting shares.
    function _sequenceRounding() internal {
        handler.deposit(50000000000000000000, 18);
        handler.borrow(500000000000000000, 20000000000000000000);
        handler.deposit(1157, 1500000000000000000);
    }

    function test_regressionRounding_defectBreaksShareAccounting() public {
        token = new MockToken();
        VaultRounding vault = new VaultRounding(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceRounding();
        assertFalse(InvariantTemplates.shareAccounting(vault, handler));
    }

    function test_regressionRounding_correctHolds() public {
        token = new MockToken();
        Vault vault = new Vault(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceRounding();
        _assertAllHold(vault);
    }

    /// D2, shrunk sequence (original 25 calls, shrunk to 4):
    /// deposit, borrow near the limit, price fall, liquidate.
    function _sequenceLiquidation() internal {
        handler.deposit(3, 80);
        handler.borrow(7627, 10357);
        handler.updatePrice(10000000000000000000000);
        handler.liquidate(4172, 9079, 50000000000000000000);
    }

    function test_regressionLiquidation_defectBreaksSolvency() public {
        token = new MockToken();
        VaultLiquidation vault = new VaultLiquidation(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceLiquidation();
        assertFalse(InvariantTemplates.solvency(vault, handler));
    }

    function test_regressionLiquidation_correctHolds() public {
        token = new MockToken();
        Vault vault = new Vault(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceLiquidation();
        _assertAllHold(vault);
    }

    /// D3, shrunk sequence (original 8 calls, shrunk to 2):
    /// deposit, borrow.
    function _sequenceFee() internal {
        handler.deposit(50000000000000000000, 18);
        handler.borrow(1000000000000000000, 10624);
    }

    function test_regressionFee_defectBreaksConservation() public {
        token = new MockToken();
        VaultFee vault = new VaultFee(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceFee();
        assertFalse(InvariantTemplates.conservation(vault, handler));
    }

    function test_regressionFee_correctHolds() public {
        token = new MockToken();
        Vault vault = new Vault(address(token), address(this));
        _fundAndHandler(address(vault));
        _sequenceFee();
        _assertAllHold(vault);
    }
}
