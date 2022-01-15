// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "@koil-finance/pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@koil-finance/pool-utils/contracts/factories/FactoryWidePauseWindow.sol";

import "./LiquidityBootstrappingPool.sol";

contract LiquidityBootstrappingPoolFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(LiquidityBootstrappingPool).creationCode) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Deploys a new `LiquidityBootstrappingPool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory weights,
        uint256 swapFeePercentage,
        address owner,
        bool swapEnabledOnStart
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();

        return
            _create(
                abi.encode(
                    getVault(),
                    name,
                    symbol,
                    tokens,
                    weights,
                    swapFeePercentage,
                    pauseWindowDuration,
                    bufferPeriodDuration,
                    owner,
                    swapEnabledOnStart
                )
            );
    }
}
