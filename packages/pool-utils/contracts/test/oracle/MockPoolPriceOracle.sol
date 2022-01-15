// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../../oracle/Samples.sol";
import "../../oracle/PoolPriceOracle.sol";
import "../../interfaces/IPriceOracle.sol";

import "./MockSamples.sol";

contract MockPoolPriceOracle is MockSamples, PoolPriceOracle {
    using Buffer for uint256;
    using Samples for bytes32;

    struct BinarySearchResult {
        uint256 prev;
        uint256 next;
    }

    event PriceDataProcessed(bool newSample, uint256 sampleIndex);

    uint256 private _mockedOracleIndex;

    function mockOracleIndex(uint256 index) external {
        _mockedOracleIndex = index;
    }

    function _getOracleIndex() internal view virtual override returns (uint256) {
        return _mockedOracleIndex;
    }

    function mockSample(uint256 index, Sample memory sample) public {
        _samples[index] = encode(sample);
    }

    function mockSamples(uint256[] memory indexes, Sample[] memory samples) public {
        for (uint256 i = 0; i < indexes.length; i++) {
            mockSample(indexes[i], samples[i]);
        }
    }

    function processPriceData(
        uint256 elapsed,
        uint256 currentIndex,
        int256 logPairPrice,
        int256 logBptPrice,
        int256 logInvariant
    ) public {
        uint256 currentSampleInitialTimestamp = block.timestamp - elapsed;
        uint256 sampleIndex = _processPriceData(
            currentSampleInitialTimestamp,
            currentIndex,
            logPairPrice,
            logBptPrice,
            logInvariant
        );
        emit PriceDataProcessed(sampleIndex != currentIndex, sampleIndex);
    }

    function findNearestSamplesTimestamp(uint256[] memory dates, uint256 offset)
        external
        view
        returns (BinarySearchResult[] memory results)
    {
        uint256 oldestIndex = _mockedOracleIndex.next();
        bytes32 oldestSample = _getSample(oldestIndex);
        uint256 oldestTimestamp = oldestSample.timestamp();
        uint256 length = oldestTimestamp > 0 ? Buffer.SIZE : oldestIndex;

        results = new BinarySearchResult[](dates.length);
        for (uint256 i = 0; i < dates.length; i++) {
            (bytes32 prev, bytes32 next) = _findNearestSample(dates[i], offset, length);
            results[i] = BinarySearchResult({ prev: prev.timestamp(), next: next.timestamp() });
        }
    }

    function getPastAccumulator(
        IPriceOracle.Variable variable,
        uint256 currentIndex,
        uint256 timestamp
    ) external view returns (int256) {
        return _getPastAccumulator(variable, currentIndex, block.timestamp - timestamp);
    }
}
