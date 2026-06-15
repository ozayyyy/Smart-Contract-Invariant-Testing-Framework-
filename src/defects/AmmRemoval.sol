// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMM} from "../AMM.sol";

/// @notice Defect D-A3 — removal burns only half the LP.
/// removeLiquidity() pays the full proportional share of both
/// reserves but burns only half of the LP it was given. The
/// remover keeps spendable LP that still claims pool value, so the
/// recorded LP supply is larger than the value actually left in the
/// pool and the same LP can be removed again. The correct code burns
/// the full amount passed in.
contract AmmRemoval is AMM {
    constructor(address _tokenA, address _tokenB) AMM(_tokenA, _tokenB) {}

    function removeLiquidity(uint256 lp) public override returns (uint256 amountA, uint256 amountB) {
        require(lp > 0, "zero lp");
        require(lpBalance[msg.sender] >= lp, "insufficient lp");
        amountA = (lp * reserveA) / totalSupply;
        amountB = (lp * reserveB) / totalSupply;
        require(amountA > 0 && amountB > 0, "zero out");
        lpBalance[msg.sender] -= lp / 2;
        totalSupply -= lp / 2;
        reserveA -= amountA;
        reserveB -= amountB;
        require(tokenA.transfer(msg.sender, amountA), "transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "transfer failed");
        emit RemoveLiquidity(msg.sender, lp, amountA, amountB);
    }
}
