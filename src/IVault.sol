// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVault {
    function asset() external view returns (address);
    function totalShares() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function totalFees() external view returns (uint256);
    function feeBps() external view returns (uint256);
    function sharesOf(address user) external view returns (uint256);
    function debtOf(address user) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function sharePrice() external view returns (uint256);
    function collateralValue(address user) external view returns (uint256);
    function maxBorrow(address user) external view returns (uint256);
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 assets);
    function transferShares(address to, uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function liquidate(address borrower, uint256 repayAmount) external;
    function accrueYield(uint256 amount) external;
    function setFee(uint256 newFeeBps) external;
    function updatePrice(uint256 newFactor) external;
    function priceFactor() external view returns (uint256);
}
