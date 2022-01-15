// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/helpers/InputHelpers.sol";
import "@koil-finance/solidity-utils/contracts/helpers/VaultHelpers.sol";
import "@koil-finance/solidity-utils/contracts/math/Math.sol";

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "@koil-finance/pool-weighted/contracts/WeightedPoolUserData.sol";

import "../interfaces/IBaseRelayerLibrary.sol";

/**
 * @title VaultActions
 * @notice Allows users to call the core functions on the Koil Vault (swaps/joins/exits/balance management)
 * @dev
 * The relayer is not expected to hold the user's funds so it is expected that the user's address will be provided
 * as the recipient of any token transfers from the Vault.
 *
 * All functions must be payable so that it can be called as part of a multicall involving FUSE
 */
abstract contract VaultActions is IBaseRelayerLibrary {
    using Math for uint256;

    struct OutputReference {
        uint256 index;
        uint256 key;
    }

    function swap(
        IVault.SingleSwap memory singleSwap,
        IVault.FundManagement calldata funds,
        uint256 limit,
        uint256 deadline,
        uint256 value,
        uint256 outputReference
    ) external payable returns (uint256) {
        require(funds.sender == msg.sender || funds.sender == address(this), "Incorrect sender");

        if (_isChainedReference(singleSwap.amount)) {
            singleSwap.amount = _getChainedReferenceValue(singleSwap.amount);
        }

        uint256 result = getVault().swap{ value: value }(singleSwap, funds, limit, deadline);

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, result);
        }

        return result;
    }

    function batchSwap(
        IVault.SwapKind kind,
        IVault.BatchSwapStep[] memory swaps,
        IAsset[] calldata assets,
        IVault.FundManagement calldata funds,
        int256[] calldata limits,
        uint256 deadline,
        uint256 value,
        OutputReference[] calldata outputReferences
    ) external payable returns (int256[] memory) {
        require(funds.sender == msg.sender || funds.sender == address(this), "Incorrect sender");

        for (uint256 i = 0; i < swaps.length; ++i) {
            uint256 amount = swaps[i].amount;
            if (_isChainedReference(amount)) {
                swaps[i].amount = _getChainedReferenceValue(amount);
            }
        }

        int256[] memory results = getVault().batchSwap{ value: value }(kind, swaps, assets, funds, limits, deadline);

        for (uint256 i = 0; i < outputReferences.length; ++i) {
            require(_isChainedReference(outputReferences[i].key), "invalid chained reference");

            // Batch swap return values are signed, as they are Vault deltas (positive values stand for assets sent
            // to the Vault, negatives for assets sent from the Vault). To simplify the chained reference value
            // model, we simply store the absolute value.
            // This should be fine for most use cases, as the caller can reason about swap results via the `limits`
            // parameter.
            _setChainedReferenceValue(outputReferences[i].key, Math.abs(results[outputReferences[i].index]));
        }

        return results;
    }

    function manageUserBalance(IVault.UserBalanceOp[] calldata ops, uint256 value) external payable {
        for (uint256 i = 0; i < ops.length; i++) {
            require(ops[i].sender == msg.sender || ops[i].sender == address(this), "Incorrect sender");
        }
        getVault().manageUserBalance{ value: value }(ops);
    }

    enum PoolKind { WEIGHTED }

    function joinPool(
        bytes32 poolId,
        PoolKind kind,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request,
        uint256 value,
        uint256 outputReference
    ) external payable {
        require(sender == msg.sender || sender == address(this), "Incorrect sender");

        // The output of a join is expected to be balance in the Pool's token contract, typically known as KPT (Koil
        // Pool Tokens). Since the Vault is unaware of this (KPT is minted directly to the recipient), we manually
        // measure this balance increase (but only if an output reference is provided).
        IERC20 bpt = IERC20(VaultHelpers.toPoolAddress(poolId));
        uint256 maybeInitialRecipientKPT = _isChainedReference(outputReference) ? bpt.balanceOf(recipient) : 0;

        request.userData = _doJoinPoolChainedReferenceReplacements(kind, request.userData);

        getVault().joinPool{ value: value }(poolId, sender, recipient, request);

        if (_isChainedReference(outputReference)) {
            // In this context, `maybeInitialRecipientKPT` is guaranteed to have been initialized, so we can safely read
            // from it. Note that we assume that the recipient balance change has a positive sign (i.e. the recipient
            // received KPT).
            uint256 finalRecipientKPT = bpt.balanceOf(recipient);
            _setChainedReferenceValue(outputReference, finalRecipientKPT.sub(maybeInitialRecipientKPT));
        }
    }

    function _doJoinPoolChainedReferenceReplacements(PoolKind kind, bytes memory userData)
        private
        returns (bytes memory)
    {
        if (kind == PoolKind.WEIGHTED) {
            return _doWeightedJoinChainedReferenceReplacements(userData);
        } else {
            _revert(Errors.UNHANDLED_JOIN_KIND);
        }
    }

    function _doWeightedJoinChainedReferenceReplacements(bytes memory userData) private returns (bytes memory) {
        WeightedPoolUserData.JoinKind kind = WeightedPoolUserData.joinKind(userData);

        if (kind == WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_KPT_OUT) {
            return _doWeightedExactTokensInForKPTOutReplacements(userData);
        } else {
            // All other join kinds are 'given out' (i.e the parameter is a KPT amount), so we don't do replacements for
            // those.
            return userData;
        }
    }

    function _doWeightedExactTokensInForKPTOutReplacements(bytes memory userData) private returns (bytes memory) {
        (uint256[] memory amountsIn, uint256 minKPTAmountOut) = WeightedPoolUserData.exactTokensInForBptOut(userData);

        bool replacedAmounts = false;
        for (uint256 i = 0; i < amountsIn.length; ++i) {
            uint256 amount = amountsIn[i];
            if (_isChainedReference(amount)) {
                amountsIn[i] = _getChainedReferenceValue(amount);
                replacedAmounts = true;
            }
        }

        // Save gas by only re-encoding the data if we actually performed a replacement
        return
            replacedAmounts
                ? abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_KPT_OUT, amountsIn, minKPTAmountOut)
                : userData;
    }

    function exitPool(
        bytes32 poolId,
        PoolKind kind,
        address sender,
        address payable recipient,
        IVault.ExitPoolRequest memory request,
        OutputReference[] calldata outputReferences
    ) external payable {
        require(sender == msg.sender || sender == address(this), "Incorrect sender");

        // To track the changes of internal balances we need an array of token addresses.
        // We save this here to avoid having to recalculate after we perform the exit.
        IERC20[] memory trackedTokens = new IERC20[](outputReferences.length);

        // Query initial balances for all tokens which we want to record into chained references
        uint256[] memory initialRecipientBalances = new uint256[](outputReferences.length);
        for (uint256 i = 0; i < outputReferences.length; i++) {
            require(_isChainedReference(outputReferences[i].key), "invalid chained reference");

            IAsset asset = request.assets[outputReferences[i].index];
            if (request.toInternalBalance) {
                trackedTokens[i] = _asIERC20(asset);
            } else {
                initialRecipientBalances[i] = _isFUSE(asset)
                    ? recipient.balance
                    : _asIERC20(asset).balanceOf(recipient);
            }
        }
        if (request.toInternalBalance) {
            initialRecipientBalances = getVault().getInternalBalance(recipient, trackedTokens);
        }

        // Execute exit from pool
        request.userData = _doExitPoolChainedReferenceReplacements(kind, request.userData);
        getVault().exitPool(poolId, sender, recipient, request);

        // Query final balances for all tokens of interest
        uint256[] memory finalRecipientTokenBalances = new uint256[](outputReferences.length);
        if (request.toInternalBalance) {
            finalRecipientTokenBalances = getVault().getInternalBalance(recipient, trackedTokens);
        } else {
            for (uint256 i = 0; i < outputReferences.length; i++) {
                IAsset asset = request.assets[outputReferences[i].index];
                finalRecipientTokenBalances[i] = _isFUSE(asset)
                    ? recipient.balance
                    : _asIERC20(asset).balanceOf(recipient);
            }
        }

        // Calculate deltas and save to chained references
        for (uint256 i = 0; i < outputReferences.length; i++) {
            _setChainedReferenceValue(
                outputReferences[i].key,
                finalRecipientTokenBalances[i].sub(initialRecipientBalances[i])
            );
        }
    }

    function _doExitPoolChainedReferenceReplacements(PoolKind kind, bytes memory userData)
        private
        returns (bytes memory)
    {
        if (kind == PoolKind.WEIGHTED) {
            return _doWeightedExitChainedReferenceReplacements(userData);
        } else {
            _revert(Errors.UNHANDLED_EXIT_KIND);
        }
    }

    function _doWeightedExitChainedReferenceReplacements(bytes memory userData) private returns (bytes memory) {
        WeightedPoolUserData.ExitKind kind = WeightedPoolUserData.exitKind(userData);

        if (kind == WeightedPoolUserData.ExitKind.EXACT_KPT_IN_FOR_ONE_TOKEN_OUT) {
            return _doWeightedExactBptInForOneTokenOutReplacements(userData);
        } else if (kind == WeightedPoolUserData.ExitKind.EXACT_KPT_IN_FOR_TOKENS_OUT) {
            return _doWeightedExactBptInForTokensOutReplacements(userData);
        } else {
            // All other exit kinds are 'given out' (i.e the parameter is a token amount),
            // so we don't do replacements for those.
            return userData;
        }
    }

    function _doWeightedExactBptInForOneTokenOutReplacements(bytes memory userData) private returns (bytes memory) {
        (uint256 bptAmountIn, uint256 tokenIndex) = WeightedPoolUserData.exactBptInForTokenOut(userData);

        if (_isChainedReference(bptAmountIn)) {
            bptAmountIn = _getChainedReferenceValue(bptAmountIn);
            return abi.encode(WeightedPoolUserData.ExitKind.EXACT_KPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, tokenIndex);
        } else {
            // Save gas by only re-encoding the data if we actually performed a replacement
            return userData;
        }
    }

    function _doWeightedExactBptInForTokensOutReplacements(bytes memory userData) private returns (bytes memory) {
        uint256 bptAmountIn = WeightedPoolUserData.exactBptInForTokensOut(userData);

        if (_isChainedReference(bptAmountIn)) {
            bptAmountIn = _getChainedReferenceValue(bptAmountIn);
            return abi.encode(WeightedPoolUserData.ExitKind.EXACT_KPT_IN_FOR_TOKENS_OUT, bptAmountIn);
        } else {
            // Save gas by only re-encoding the data if we actually performed a replacement
            return userData;
        }
    }
}
