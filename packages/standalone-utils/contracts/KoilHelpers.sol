// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/math/Math.sol";
import "@koil-finance/solidity-utils/contracts/math/FixedPoint.sol";

import "@koil-finance/solidity-utils/contracts/helpers/InputHelpers.sol";
import "@koil-finance/solidity-utils/contracts/helpers/KoilErrors.sol";

import "@koil-finance/solidity-utils/contracts/misc/IWFUSE.sol";

import "@koil-finance/vault/contracts/AssetHelpers.sol";
import "@koil-finance/vault/contracts/interfaces/IVault.sol";
import "@koil-finance/vault/contracts/balances/BalanceAllocation.sol";

import "@koil-finance/pool-utils/contracts/BasePool.sol";

/**
 * @dev This contract simply builds on top of the Koil architecture to provide useful helpers to users.
 * It connects different functionalities of the protocol components to allow accessing information that would
 * have required a more cumbersome setup if we wanted to provide these already built-in.
 */
contract KoilHelpers is AssetHelpers {
    using Math for uint256;
    using BalanceAllocation for bytes32;
    using BalanceAllocation for bytes32[];

    IVault public immutable vault;

    constructor(IVault _vault) AssetHelpers(_vault.WFUSE()) {
        vault = _vault;
    }

    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn) {
        (address pool, ) = vault.getPool(poolId);
        (uint256[] memory balances, uint256 lastChangeBlock) = _validateAssetsAndGetBalances(poolId, request.assets);
        IProtocolFeesCollector feesCollector = vault.getProtocolFeesCollector();

        (bptOut, amountsIn) = BasePool(pool).queryJoin(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            feesCollector.getSwapFeePercentage(),
            request.userData
        );
    }

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut) {
        (address pool, ) = vault.getPool(poolId);
        (uint256[] memory balances, uint256 lastChangeBlock) = _validateAssetsAndGetBalances(poolId, request.assets);
        IProtocolFeesCollector feesCollector = vault.getProtocolFeesCollector();

        (bptIn, amountsOut) = BasePool(pool).queryExit(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            feesCollector.getSwapFeePercentage(),
            request.userData
        );
    }

    function _validateAssetsAndGetBalances(bytes32 poolId, IAsset[] memory expectedAssets)
        internal
        view
        returns (uint256[] memory balances, uint256 lastChangeBlock)
    {
        IERC20[] memory actualTokens;
        IERC20[] memory expectedTokens = _translateToIERC20(expectedAssets);

        (actualTokens, balances, lastChangeBlock) = vault.getPoolTokens(poolId);
        InputHelpers.ensureInputLengthMatch(actualTokens.length, expectedTokens.length);

        for (uint256 i = 0; i < actualTokens.length; ++i) {
            IERC20 token = actualTokens[i];
            _require(token == expectedTokens[i], Errors.TOKENS_MISMATCH);
        }
    }
}
