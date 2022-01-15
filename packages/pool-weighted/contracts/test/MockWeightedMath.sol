// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../WeightedMath.sol";

contract MockWeightedMath {
    function invariant(uint256[] memory normalizedWeights, uint256[] memory balances) external pure returns (uint256) {
        return WeightedMath._calculateInvariant(normalizedWeights, balances);
    }

    function outGivenIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountIn
    ) external pure returns (uint256) {
        return
            WeightedMath._calcOutGivenIn(tokenBalanceIn, tokenWeightIn, tokenBalanceOut, tokenWeightOut, tokenAmountIn);
    }

    function inGivenOut(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountOut
    ) external pure returns (uint256) {
        return
            WeightedMath._calcInGivenOut(
                tokenBalanceIn,
                tokenWeightIn,
                tokenBalanceOut,
                tokenWeightOut,
                tokenAmountOut
            );
    }

    function exactTokensInForKPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        (uint256 bptOut, ) = WeightedMath._calcBptOutGivenExactTokensIn(
            balances,
            normalizedWeights,
            amountsIn,
            bptTotalSupply,
            swapFee
        );
        return bptOut;
    }

    function tokenInForExactKPTOut(
        uint256 tokenBalance,
        uint256 tokenNormalizedWeight,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        (uint256 amountIn, ) = WeightedMath._calcTokenInGivenExactBptOut(
            tokenBalance,
            tokenNormalizedWeight,
            bptAmountOut,
            bptTotalSupply,
            swapFee
        );
        return amountIn;
    }

    function exactKPTInForTokenOut(
        uint256 tokenBalance,
        uint256 tokenNormalizedWeight,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        (uint256 amountOut, ) = WeightedMath._calcTokenOutGivenExactBptIn(
            tokenBalance,
            tokenNormalizedWeight,
            bptAmountIn,
            bptTotalSupply,
            swapFee
        );
        return amountOut;
    }

    function exactKPTInForTokensOut(
        uint256[] memory currentBalances,
        uint256 bptAmountIn,
        uint256 totalKPT
    ) external pure returns (uint256[] memory) {
        return WeightedMath._calcTokensOutGivenExactBptIn(currentBalances, bptAmountIn, totalKPT);
    }

    function bptInForExactTokensOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        (uint256 bptIn, ) = WeightedMath._calcBptInGivenExactTokensOut(
            balances,
            normalizedWeights,
            amountsOut,
            bptTotalSupply,
            swapFee
        );
        return bptIn;
    }

    function calculateDueTokenProtocolSwapFeeAmount(
        uint256 balance,
        uint256 normalizedWeight,
        uint256 previousInvariant,
        uint256 currentInvariant,
        uint256 protocolSwapFeePercentage
    ) external pure returns (uint256) {
        return
            WeightedMath._calcDueTokenProtocolSwapFeeAmount(
                balance,
                normalizedWeight,
                previousInvariant,
                currentInvariant,
                protocolSwapFeePercentage
            );
    }
}
