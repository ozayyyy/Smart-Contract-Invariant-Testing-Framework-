// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMM} from "../AMM.sol";

/// @notice Defect D-A1 — swap charges no fee.
/// swap() pays the fee-free output amountIn * reserveOut /
/// (reserveIn + amountIn) instead of the 0.3%-fee formula. Traders
/// receive more than the quoted amount on every swap, so the reserves
/// fall short of the ghost reserves and the paid output no longer
/// matches the fee formula. The correct code uses getAmountOut with
/// the 997/1000 fee.
contract AmmNoFee is AMM {
    constructor(address _tokenA, address _tokenB) AMM(_tokenA, _tokenB) {}

    function swap(uint256 amountIn, bool aForB) public override returns (uint256 amountOut) {
        require(amountIn > 0, "zero swap");
        uint256 reserveIn = aForB ? reserveA : reserveB;
        uint256 reserveOut = aForB ? reserveB : reserveA;
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut > 0 && amountOut < reserveOut, "insufficient output");
        if (aForB) {
            require(tokenA.transferFrom(msg.sender, address(this), amountIn), "transfer failed");
            require(tokenB.transfer(msg.sender, amountOut), "transfer failed");
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            require(tokenB.transferFrom(msg.sender, address(this), amountIn), "transfer failed");
            require(tokenA.transfer(msg.sender, amountOut), "transfer failed");
            reserveB += amountIn;
            reserveA -= amountOut;
        }
        emit Swap(msg.sender, aForB, amountIn, amountOut);
    }
}
