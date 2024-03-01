// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../Vault.sol";

/// @notice Defect D3 — borrow under-records debt.
/// borrow() transfers the full borrowed amount to the borrower but
/// records only 95% of it as debt and charges no fee. Five percent of
/// every loan vanishes from the accounting: vault balance plus
/// recorded debt no longer equals deposits plus yield plus fees.
/// The correct code records amount plus the 1% fee as debt.
contract VaultFee is Vault {
    constructor(address _asset, address _owner) Vault(_asset, _owner) {}

    function borrow(uint256 amount) public override {
        require(amount > 0, "zero borrow");
        require(debt[msg.sender] + amount <= maxBorrow(msg.sender), "exceeds max borrow");
        require(amount <= assetToken.balanceOf(address(this)), "insufficient liquidity");
        uint256 recorded = (amount * 95) / 100;
        debt[msg.sender] += recorded;
        totalDebt += recorded;
        require(assetToken.transfer(msg.sender, amount), "transfer failed");
        emit Borrow(msg.sender, amount, 0);
    }
}
