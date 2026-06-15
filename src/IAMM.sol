// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAMM {
    function MINIMUM_LIQUIDITY() external view returns (uint256);
    function reserveA() external view returns (uint256);
    function reserveB() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function lpBalance(address user) external view returns (uint256);
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256);
    function getLiquidityOut(uint256 amountA, uint256 amountB) external view returns (uint256);
    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lp);
    function removeLiquidity(uint256 lp) external returns (uint256 amountA, uint256 amountB);
    function swap(uint256 amountIn, bool aForB) external returns (uint256 amountOut);
}
