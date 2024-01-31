// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockToken} from "./MockToken.sol";
import {IVault} from "./IVault.sol";

/// @title Vault — example deposit / borrow / liquidate protocol.
/// @notice Shares are proportional claims on totalAssets (vault asset
/// balance plus outstanding debt). One share is worth sharePrice().
/// Borrowers post shares as collateral and may borrow up to 75% of
/// their collateral value. A 1% origination fee is added to the debt,
/// so the fee accrues to the vault. Liquidation requires the borrower
/// to be under-collateralised, repays part of the debt, and seizes
/// collateral at a 10% discount to the repaid amount, capped at the
/// borrower's shares.
/// @dev Functions are virtual so seeded-defect variants can override
/// exactly one behaviour each. All amounts are raw token units.
contract Vault is IVault {
    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LTV_BPS = 7500;
    uint256 public constant LIQ_BONUS_BPS = 1000;

    MockToken public immutable assetToken;
    address public owner;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public debt;
    uint256 public totalShares;
    uint256 public totalDebt;
    uint256 public totalFees;
    uint256 public feeBps = 100;
    /// @notice Collateral price factor, in WAD. 1e18 is par. The owner
    /// (modelling a price oracle) can move it; a fall makes borrowers
    /// liquidatable. It only affects collateral valuation, never
    /// redemption value.
    uint256 public priceFactor = 1e18;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 assets);
    event Borrow(address indexed user, uint256 amount, uint256 fee);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 repaid, uint256 seized);

    constructor(address _asset, address _owner) {
        assetToken = MockToken(_asset);
        owner = _owner;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function sharesOf(address user) external view returns (uint256) {
        return shares[user];
    }

    function debtOf(address user) external view returns (uint256) {
        return debt[user];
    }

    function totalAssets() public view returns (uint256) {
        return assetToken.balanceOf(address(this)) + totalDebt;
    }

    function sharePrice() public view returns (uint256) {
        if (totalShares == 0) return WAD;
        return (totalAssets() * WAD) / totalShares;
    }

    function collateralValue(address user) public view returns (uint256) {
        return (shares[user] * sharePrice() * priceFactor) / WAD / WAD;
    }

    function maxBorrow(address user) public view returns (uint256) {
        return (collateralValue(user) * MAX_LTV_BPS) / 10000;
    }

    function deposit(uint256 amount) public virtual returns (uint256 minted) {
        require(amount > 0, "zero deposit");
        uint256 assetsBefore = totalAssets();
        uint256 sharesBefore = totalShares;
        require(assetToken.transferFrom(msg.sender, address(this), amount), "transfer failed");
        if (sharesBefore == 0) {
            minted = amount;
        } else {
            minted = (amount * sharesBefore) / assetsBefore;
        }
        require(minted > 0, "zero shares");
        shares[msg.sender] += minted;
        totalShares += minted;
        emit Deposit(msg.sender, amount, minted);
    }

    function withdraw(uint256 sharesAmount) public virtual returns (uint256 assetsOut) {
        require(sharesAmount > 0, "zero withdraw");
        require(shares[msg.sender] >= sharesAmount, "insufficient shares");
        assetsOut = (sharesAmount * totalAssets()) / totalShares;
        require(assetsOut <= assetToken.balanceOf(address(this)), "insufficient liquidity");
        shares[msg.sender] -= sharesAmount;
        totalShares -= sharesAmount;
        require(assetToken.transfer(msg.sender, assetsOut), "transfer failed");
        // Checked after the transfer, so sharePrice() reflects the
        // post-withdraw total assets. Checked before it, the price
        // would be inflated by the not-yet-transferred assets.
        require(debt[msg.sender] <= maxBorrow(msg.sender), "withdraw would break solvency");
        emit Withdraw(msg.sender, sharesAmount, assetsOut);
    }

    function transferShares(address to, uint256 amount) public virtual {
        require(to != address(0), "zero address");
        require(shares[msg.sender] >= amount, "insufficient shares");
        shares[msg.sender] -= amount;
        shares[to] += amount;
        require(debt[msg.sender] <= maxBorrow(msg.sender), "transfer would break solvency");
    }

    function borrow(uint256 amount) public virtual {
        require(amount > 0, "zero borrow");
        uint256 fee = (amount * feeBps) / 10000;
        require(debt[msg.sender] + amount + fee <= maxBorrow(msg.sender), "exceeds max borrow");
        require(amount <= assetToken.balanceOf(address(this)), "insufficient liquidity");
        debt[msg.sender] += amount + fee;
        totalDebt += amount + fee;
        totalFees += fee;
        require(assetToken.transfer(msg.sender, amount), "transfer failed");
        emit Borrow(msg.sender, amount, fee);
    }

    function repay(uint256 amount) public virtual {
        require(amount > 0, "zero repay");
        uint256 pay = amount > debt[msg.sender] ? debt[msg.sender] : amount;
        require(pay > 0, "no debt");
        require(assetToken.transferFrom(msg.sender, address(this), pay), "transfer failed");
        debt[msg.sender] -= pay;
        totalDebt -= pay;
        emit Repay(msg.sender, pay);
    }

    function liquidate(address borrower, uint256 repayAmount) public virtual {
        require(borrower != msg.sender, "self liquidation");
        require(debt[borrower] > maxBorrow(borrower), "borrower is healthy");
        uint256 pay = repayAmount > debt[borrower] ? debt[borrower] : repayAmount;
        require(pay > 0, "no debt");
        // Never repay more than the borrower's collateral can cover:
        // seized shares are worth pay plus the 10% bonus, so the
        // repaid amount is capped by the collateral's redemption value.
        uint256 maxPay = ((shares[borrower] * sharePrice()) / WAD * 10000) / 11000;
        if (pay > maxPay) pay = maxPay;
        require(pay > 0, "no collateral");
        require(assetToken.transferFrom(msg.sender, address(this), pay), "transfer failed");
        debt[borrower] -= pay;
        totalDebt -= pay;
        uint256 seized = (pay * WAD) / sharePrice();
        seized = (seized * (10000 + LIQ_BONUS_BPS)) / 10000;
        if (seized > shares[borrower]) seized = shares[borrower];
        shares[borrower] -= seized;
        shares[msg.sender] += seized;
        emit Liquidate(msg.sender, borrower, pay, seized);
    }

    /// @notice Donate asset to the vault. No shares are minted, so the
    /// share price rises. Models interest / yield accruing to depositors.
    function accrueYield(uint256 amount) public virtual {
        require(amount > 0, "zero yield");
        require(assetToken.transferFrom(msg.sender, address(this), amount), "transfer failed");
    }

    function setFee(uint256 newFeeBps) public virtual {
        require(msg.sender == owner, "only owner");
        require(newFeeBps <= 1000, "fee too high");
        feeBps = newFeeBps;
    }

    function updatePrice(uint256 newFactor) public virtual {
        require(msg.sender == owner, "only owner");
        require(newFactor >= 5e17 && newFactor <= 15e17, "price out of range");
        priceFactor = newFactor;
    }
}
