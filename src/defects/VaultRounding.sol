// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../Vault.sol";

/// @notice Defect D1 — share rounding / 1:1 mint.
/// deposit() mints shares equal to the deposited amount, ignoring the
/// share price. After yield accrues, a new depositor receives far more
/// shares than their deposit is worth and can withdraw value that
/// belongs to earlier depositors. The correct code mints
/// amount * totalShares / totalAssets.
contract VaultRounding is Vault {
    constructor(address _asset, address _owner) Vault(_asset, _owner) {}

    function deposit(uint256 amount) public override returns (uint256 minted) {
        require(amount > 0, "zero deposit");
        require(assetToken.transferFrom(msg.sender, address(this), amount), "transfer failed");
        minted = amount;
        require(minted > 0, "zero shares");
        shares[msg.sender] += minted;
        totalShares += minted;
        emit Deposit(msg.sender, amount, minted);
    }
}
