// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/test/MockLogCompression.sol";

import "../WeightedOracleMath.sol";

contract MockWeightedOracleMath is WeightedOracleMath, MockLogCompression {
    function calcLogSpotPrice(
        uint256 normalizedWeightA,
        uint256 balanceA,
        uint256 normalizedWeightB,
        uint256 balanceB
    ) external pure returns (int256) {
        return WeightedOracleMath._calcLogSpotPrice(normalizedWeightA, balanceA, normalizedWeightB, balanceB);
    }

    function calcLogKPTPrice(
        uint256 normalizedWeight,
        uint256 balance,
        int256 bptTotalSupplyLn
    ) external pure returns (int256) {
        return WeightedOracleMath._calcLogKPTPrice(normalizedWeight, balance, bptTotalSupplyLn);
    }
}
