// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAMM} from "../IAMM.sol";
import {AmmHandler} from "../harness/AmmHandler.sol";

/// @title AMM invariant templates.
/// @notice Each template is one reusable property with a stated
/// assumption and scope (see docs/invariants.md). They compare the
/// pool's actual state against the handler's ghost accounting, which
/// is computed independently from the pool's state before each call.
/// The swap and removal templates only apply when the last action
/// was that kind; otherwise they hold by default. Tolerances are in
/// wei and cover only integer-division rounding on ether-scale
/// amounts; they are far smaller than any real defect.
/// @dev A property returning false is a broken invariant, not a
/// reverted call. Tests assert each template after every sequence.
library AmmInvariantTemplates {
    uint256 internal constant TOLERANCE = 100;

    function _diff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /// AMM-1 reserve accounting: the reserves equal the ghost
    /// reserves implied by adds, swaps and removals.
    function reserveAccounting(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (_diff(amm.reserveA(), handler.expectedReserveA()) > TOLERANCE) return false;
        if (_diff(amm.reserveB(), handler.expectedReserveB()) > TOLERANCE) return false;
        return true;
    }

    /// AMM-2 LP accounting: summed LP plus the locked minimum equals
    /// total supply (once initialised), each actor's LP equals the
    /// ghost LP implied by their adds and removals, and the ghost
    /// total supply equals the recorded total supply.
    function lpAccounting(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (amm.totalSupply() == 0) {
            return handler.sumLp() == 0 && handler.ghostTotalSupply() == 0;
        }
        if (handler.sumLp() + amm.MINIMUM_LIQUIDITY() != amm.totalSupply()) return false;
        if (_diff(handler.ghostTotalSupply(), amm.totalSupply()) > TOLERANCE) return false;
        for (uint256 i = 0; i < 4; i++) {
            address actor = handler.actors(i);
            if (_diff(amm.lpBalance(actor), handler.expectedLp(actor)) > TOLERANCE) return false;
        }
        return true;
    }

    /// AMM-3 swap fairness: the last swap paid exactly the output
    /// the 0.3%-fee formula gives for its pre-swap reserves.
    function swapFairness(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (handler.lastAction() != handler.LAST_SWAP()) return true;
        uint256 expected = amm.getAmountOut(
            handler.lastSwapAmountIn(), handler.lastSwapReserveIn(), handler.lastSwapReserveOut()
        );
        return _diff(handler.lastSwapActualOut(), expected) <= TOLERANCE;
    }

    /// AMM-4 product growth: the last swap did not shrink the
    /// product of the reserves. The fee stays in the pool, so the
    /// product grows on every swap; a fee-free swap keeps it flat.
    function productGrowth(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (handler.lastAction() != handler.LAST_SWAP()) return true;
        uint256 before = handler.lastSwapReserveIn() * handler.lastSwapReserveOut();
        uint256 after_ = amm.reserveA() * amm.reserveB();
        return after_ >= before;
    }

    /// AMM-5 removal proportionality: the last removal paid the
    /// proportional share of both pre-removal reserves.
    function removalProportionality(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (handler.lastAction() != handler.LAST_REMOVE()) return true;
        uint256 expectedA = (handler.lastRemoveLp() * handler.lastRemoveReserveA())
            / handler.lastRemoveSupply();
        uint256 expectedB = (handler.lastRemoveLp() * handler.lastRemoveReserveB())
            / handler.lastRemoveSupply();
        if (_diff(handler.lastRemoveOutA(), expectedA) > TOLERANCE) return false;
        if (_diff(handler.lastRemoveOutB(), expectedB) > TOLERANCE) return false;
        return true;
    }

    /// AMM-6 no drain: while LP exists, both reserves are positive,
    /// and no actor holds more LP than the total supply.
    function noDrain(IAMM amm, AmmHandler handler) internal view returns (bool) {
        if (amm.totalSupply() == 0) return true;
        if (amm.reserveA() == 0 || amm.reserveB() == 0) return false;
        for (uint256 i = 0; i < 4; i++) {
            if (amm.lpBalance(handler.actors(i)) > amm.totalSupply()) return false;
        }
        return true;
    }
}
