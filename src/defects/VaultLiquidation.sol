// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../Vault.sol";

/// @notice Defect D2 — liquidation leaves bad debt.
/// liquidate() seizes the borrower's entire collateral and reduces the
/// debt by only half of the repaid amount. The borrower is left with
/// outstanding debt and no collateral, so the protocol holds bad debt
/// that no collateral covers. The correct code reduces the debt by the
/// full repaid amount and seizes collateral proportional to it.
contract VaultLiquidation is Vault {
    constructor(address _asset, address _owner) Vault(_asset, _owner) {}

    function liquidate(address borrower, uint256 repayAmount) public override {
        require(borrower != msg.sender, "self liquidation");
        require(debt[borrower] > maxBorrow(borrower), "borrower is healthy");
        uint256 pay = repayAmount > debt[borrower] ? debt[borrower] : repayAmount;
        require(pay > 0, "no debt");
        require(assetToken.transferFrom(msg.sender, address(this), pay), "transfer failed");
        debt[borrower] -= pay / 2;
        totalDebt -= pay / 2;
        uint256 seized = shares[borrower];
        shares[borrower] = 0;
        shares[msg.sender] += seized;
        emit Liquidate(msg.sender, borrower, pay, seized);
    }
}
