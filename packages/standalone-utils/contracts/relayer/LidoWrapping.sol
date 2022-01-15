// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/openzeppelin/Address.sol";

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "../interfaces/IBaseRelayerLibrary.sol";
import "../interfaces/IstFUSE.sol";
import "../interfaces/IwstFUSE.sol";

/**
 * @title LidoWrapping
 * @notice Allows users to wrap and unwrap stFUSE as one of
 * @dev All functions must be payable so that it can be called as part of a multicall involving FUSE
 */
abstract contract LidoWrapping is IBaseRelayerLibrary {
    using Address for address payable;

    IstFUSE private immutable _stFUSE;
    IwstFUSE private immutable _wstFUSE;

    /**
     * @dev The zero address may be passed as wstFUSE to safely disable this module
     * @param wstFUSE - the address of the Lido's wrapped stFUSE contract
     */
    constructor(IERC20 wstFUSE) {
        // Safely disable stFUSE wrapping if no address has been passed for wstFUSE
        _stFUSE = wstFUSE != IERC20(0) ? IwstFUSE(address(wstFUSE)).stFUSE() : IstFUSE(0);
        _wstFUSE = IwstFUSE(address(wstFUSE));
    }

    function wrapStFUSE(
        address sender,
        address recipient,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        // The wrap caller is the implicit sender of tokens, so if the goal is for the tokens
        // to be sourced from outside the relayer, we must first them pull them here.
        if (sender != address(this)) {
            require(sender == msg.sender, "Incorrect sender");
            _pullToken(sender, _stFUSE, amount);
        }

        _stFUSE.approve(address(_wstFUSE), amount);
        uint256 result = IwstFUSE(_wstFUSE).wrap(amount);

        if (recipient != address(this)) {
            _wstFUSE.transfer(recipient, result);
        }

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, result);
        }
    }

    function unwrapWstFUSE(
        address sender,
        address recipient,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        // The unwrap caller is the implicit sender of tokens, so if the goal is for the tokens
        // to be sourced from outside the relayer, we must first them pull them here.
        if (sender != address(this)) {
            require(sender == msg.sender, "Incorrect sender");
            _pullToken(sender, _wstFUSE, amount);
        }

        // No approval is needed here as wstFUSE is burned directly from the relayer's account
        uint256 result = _wstFUSE.unwrap(amount);

        if (recipient != address(this)) {
            _stFUSE.transfer(recipient, result);
        }

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, result);
        }
    }

    function stakeFUSE(
        address recipient,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        uint256 result = _stFUSE.submit{ value: amount }(address(this));

        if (recipient != address(this)) {
            _stFUSE.transfer(recipient, result);
        }

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, result);
        }
    }

    function stakeFUSEAndWrap(
        address recipient,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        // As the wstFUSE contract doesn't return how much wstFUSE is minted we must query this separately.
        uint256 result = _wstFUSE.getWstFUSEByStFUSE(amount);

        // The fallback function on the wstFUSE contract automatically stakes and wraps any FUSE which is sent to it.
        // We can then safely just send the FUSE and just have to ensure that the call doesn't revert.
        //
        // This would be dangerous should `_wstFUSE` be set to the zero address, however in this scenario
        // this function would have already reverted on when calling `getWstFUSEByStFUSE`, preventing loss of funds.
        payable(address(_wstFUSE)).sendValue(amount);

        if (recipient != address(this)) {
            _wstFUSE.transfer(recipient, result);
        }

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, result);
        }
    }
}
