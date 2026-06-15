// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockToken} from "./MockToken.sol";
import {IAMM} from "./IAMM.sol";

/// @title AMM — example constant-product market maker.
/// @notice Two-token pool with LP shares. The first liquidity provider
/// mints sqrt(amountA * amountB) LP minus a minimum liquidity of
/// 1000, which is locked in the pool forever (as in Uniswap V2), so
/// the pool can never be fully drained of LP. Later providers mint
/// the smaller of the two proportional amounts, so imbalanced adds
/// are priced by the scarcer side. Swaps charge a 0.3% fee, which
/// stays in the reserves and grows the product of the reserves.
/// Removing liquidity burns LP and pays the proportional share of
/// both reserves.
/// @dev Functions are virtual so seeded-defect variants can override
/// exactly one behaviour each. All amounts are raw token units.
contract AMM is IAMM {
    uint256 public constant FEE_NUM = 997;
    uint256 public constant FEE_DEN = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    MockToken public tokenA;
    MockToken public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    mapping(address => uint256) public lpBalance;

    event AddLiquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 lp);
    event RemoveLiquidity(address indexed user, uint256 lp, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, bool aForB, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = MockToken(_tokenA);
        tokenB = MockToken(_tokenB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "bad quote");
        uint256 amountInWithFee = amountIn * FEE_NUM;
        return (amountInWithFee * reserveOut) / (reserveIn * FEE_DEN + amountInWithFee);
    }

    function getLiquidityOut(uint256 amountA, uint256 amountB) public view returns (uint256 lp) {
        if (totalSupply == 0) {
            lp = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        } else {
            uint256 lpA = (amountA * totalSupply) / reserveA;
            uint256 lpB = (amountB * totalSupply) / reserveB;
            lp = lpA < lpB ? lpA : lpB;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) public virtual returns (uint256 lp) {
        require(amountA > 0 && amountB > 0, "zero liquidity");
        lp = getLiquidityOut(amountA, amountB);
        require(lp > 0, "zero lp");
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "transfer failed");
        if (totalSupply == 0) {
            // Lock the minimum liquidity in the pool forever.
            totalSupply += MINIMUM_LIQUIDITY;
        }
        lpBalance[msg.sender] += lp;
        totalSupply += lp;
        reserveA += amountA;
        reserveB += amountB;
        emit AddLiquidity(msg.sender, amountA, amountB, lp);
    }

    function removeLiquidity(uint256 lp) public virtual returns (uint256 amountA, uint256 amountB) {
        require(lp > 0, "zero lp");
        require(lpBalance[msg.sender] >= lp, "insufficient lp");
        amountA = (lp * reserveA) / totalSupply;
        amountB = (lp * reserveB) / totalSupply;
        require(amountA > 0 && amountB > 0, "zero out");
        lpBalance[msg.sender] -= lp;
        totalSupply -= lp;
        reserveA -= amountA;
        reserveB -= amountB;
        require(tokenA.transfer(msg.sender, amountA), "transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "transfer failed");
        emit RemoveLiquidity(msg.sender, lp, amountA, amountB);
    }

    function swap(uint256 amountIn, bool aForB) public virtual returns (uint256 amountOut) {
        require(amountIn > 0, "zero swap");
        uint256 reserveIn = aForB ? reserveA : reserveB;
        uint256 reserveOut = aForB ? reserveB : reserveA;
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
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

    /// @notice Babylonian square root, rounded down.
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
