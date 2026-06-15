// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMM} from "../AMM.sol";

/// @notice Defect D-A2 — liquidity mints LP 1:1 with token A.
/// addLiquidity() mints LP equal to the token A amount, ignoring
/// the reserve ratio, the existing supply, and the minimum
/// liquidity lock. An imbalanced or later add over-mints LP, so the
/// new provider owns far more of the pool than their deposit is
/// worth and can withdraw value that belongs to earlier providers.
/// The correct code mints sqrt(amountA * amountB) minus the minimum
/// on the first add, and the smaller proportional amount afterwards.
contract AmmLiquidity is AMM {
    constructor(address _tokenA, address _tokenB) AMM(_tokenA, _tokenB) {}

    function addLiquidity(uint256 amountA, uint256 amountB) public override returns (uint256 lp) {
        require(amountA > 0 && amountB > 0, "zero liquidity");
        lp = amountA;
        require(lp > 0, "zero lp");
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "transfer failed");
        lpBalance[msg.sender] += lp;
        totalSupply += lp;
        reserveA += amountA;
        reserveB += amountB;
        emit AddLiquidity(msg.sender, amountA, amountB, lp);
    }
}
