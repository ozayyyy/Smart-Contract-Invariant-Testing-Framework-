// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../MockToken.sol";
import {IAMM} from "../IAMM.sol";

/// @title AmmHandler — stateful driver for AMM invariant testing.
/// @notice Mirrors src/harness/Handler.sol for the vault. The fuzzer
/// calls these functions with arbitrary seeds. Each function acts as
/// one of four actors, bounds its amounts, and records ghost state:
/// the reserves and LP balances the pool *should* have, computed from
/// the pool's own state before the call using the correct formulas
/// (0.3% swap fee, proportional LP minting). Invariants compare the
/// pool's actual state against this ghost state. Calls that revert
/// change nothing and are not recorded — a revert is not a failure.
/// @dev The handler inherits Test so it can use vm.prank to act as
/// each actor.
contract AmmHandler is Test {
    uint8 public constant LAST_NONE = 0;
    uint8 public constant LAST_ADD = 1;
    uint8 public constant LAST_SWAP = 2;
    uint8 public constant LAST_REMOVE = 3;

    MockToken public tokenA;
    MockToken public tokenB;
    IAMM public amm;
    address[4] public actors;

    // Ghost accounting (intended values, computed independently).
    uint256 public expectedReserveA;
    uint256 public expectedReserveB;
    mapping(address => uint256) public expectedLp;
    uint256 public ghostTotalSupply;
    bool public initialized;
    uint256 public ghostCalls;

    mapping(bytes32 => uint256) public callCounts;

    // Last-action records, for the swap and removal templates. They
    // only describe the most recent successful call, and the
    // templates check them only when the last action was that kind.
    uint8 public lastAction;
    uint256 public lastSwapAmountIn;
    uint256 public lastSwapActualOut;
    uint256 public lastSwapReserveIn;
    uint256 public lastSwapReserveOut;
    uint256 public lastRemoveLp;
    uint256 public lastRemoveOutA;
    uint256 public lastRemoveOutB;
    uint256 public lastRemoveReserveA;
    uint256 public lastRemoveReserveB;
    uint256 public lastRemoveSupply;

    constructor(address _tokenA, address _tokenB, address _amm, address[4] memory _actors) {
        tokenA = MockToken(_tokenA);
        tokenB = MockToken(_tokenB);
        amm = IAMM(_amm);
        actors = _actors;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, 3)];
    }

    function _count(string memory name) internal {
        callCounts[keccak256(bytes(name))]++;
        ghostCalls++;
    }

    function addLiquidity(uint256 actorSeed, uint256 amountASeed, uint256 amountBSeed) public {
        address actor = _actor(actorSeed);
        uint256 amountA = bound(amountASeed, 1 ether, 50 ether);
        uint256 amountB = bound(amountBSeed, 1 ether, 50 ether);
        if (tokenA.balanceOf(actor) < amountA || tokenB.balanceOf(actor) < amountB) return;
        uint256 lp = amm.getLiquidityOut(amountA, amountB);
        if (lp == 0) return;
        bool first = amm.totalSupply() == 0;
        _count("addLiquidity");
        vm.prank(actor);
        try amm.addLiquidity(amountA, amountB) {
            expectedReserveA += amountA;
            expectedReserveB += amountB;
            expectedLp[actor] += lp;
            ghostTotalSupply += lp;
            if (first) {
                ghostTotalSupply += amm.MINIMUM_LIQUIDITY();
                initialized = true;
            }
            lastAction = LAST_ADD;
        } catch {}
    }

    function swap(uint256 actorSeed, uint256 amountSeed, uint256 dirSeed) public {
        address actor = _actor(actorSeed);
        bool aForB = bound(dirSeed, 0, 1) == 0;
        MockToken tokenIn = aForB ? tokenA : tokenB;
        uint256 amount = bound(amountSeed, 1 ether, 10 ether);
        if (tokenIn.balanceOf(actor) < amount) return;
        uint256 reserveIn = aForB ? amm.reserveA() : amm.reserveB();
        uint256 reserveOut = aForB ? amm.reserveB() : amm.reserveA();
        if (reserveIn == 0 || reserveOut == 0) return;
        uint256 expectedOut = amm.getAmountOut(amount, reserveIn, reserveOut);
        if (expectedOut == 0 || expectedOut >= reserveOut) return;
        _count("swap");
        vm.prank(actor);
        try amm.swap(amount, aForB) returns (uint256 actualOut) {
            if (aForB) {
                expectedReserveA += amount;
                expectedReserveB -= expectedOut;
            } else {
                expectedReserveB += amount;
                expectedReserveA -= expectedOut;
            }
            lastSwapAmountIn = amount;
            lastSwapActualOut = actualOut;
            lastSwapReserveIn = reserveIn;
            lastSwapReserveOut = reserveOut;
            lastAction = LAST_SWAP;
        } catch {}
    }

    function removeLiquidity(uint256 actorSeed, uint256 lpSeed) public {
        address actor = _actor(actorSeed);
        uint256 held = amm.lpBalance(actor);
        if (held == 0) return;
        uint256 lp = bound(lpSeed, 1, held);
        uint256 supply = amm.totalSupply();
        uint256 outA = (lp * amm.reserveA()) / supply;
        uint256 outB = (lp * amm.reserveB()) / supply;
        if (outA == 0 || outB == 0) return;
        uint256 reserveABefore = amm.reserveA();
        uint256 reserveBBefore = amm.reserveB();
        _count("removeLiquidity");
        vm.prank(actor);
        try amm.removeLiquidity(lp) returns (uint256 actualA, uint256 actualB) {
            expectedReserveA -= outA;
            expectedReserveB -= outB;
            expectedLp[actor] -= lp;
            ghostTotalSupply -= lp;
            lastRemoveLp = lp;
            lastRemoveOutA = actualA;
            lastRemoveOutB = actualB;
            lastRemoveReserveA = reserveABefore;
            lastRemoveReserveB = reserveBBefore;
            lastRemoveSupply = supply;
            lastAction = LAST_REMOVE;
        } catch {}
    }

    function sumLp() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += amm.lpBalance(actors[i]);
    }

    function sumExpectedLp() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += expectedLp[actors[i]];
    }
}
