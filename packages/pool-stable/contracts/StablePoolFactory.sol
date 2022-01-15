// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "@koil-finance/pool-utils/contracts/factories/BasePoolFactory.sol";
import "@koil-finance/pool-utils/contracts/factories/FactoryWidePauseWindow.sol";

import "./StablePool.sol";

contract StablePoolFactory is BasePoolFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolFactory(vault) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Deploys a new `StablePool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256 amplificationParameter,
        uint256 swapFeePercentage,
        address owner
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();

        address pool = address(
            new StablePool(
                getVault(),
                name,
                symbol,
                tokens,
                amplificationParameter,
                swapFeePercentage,
                pauseWindowDuration,
                bufferPeriodDuration,
                owner
            )
        );
        _register(pool);
        return pool;
    }
}
