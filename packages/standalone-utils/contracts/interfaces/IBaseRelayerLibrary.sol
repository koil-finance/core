// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/vault/contracts/AssetHelpers.sol";
import "@koil-finance/vault/contracts/interfaces/IVault.sol";

/**
 * @title IBaseRelayerLibrary
 */
abstract contract IBaseRelayerLibrary is AssetHelpers {
    constructor(IWFUSE wfuse) AssetHelpers(wfuse) {
        // solhint-disable-previous-line no-empty-blocks
    }

    function getVault() public view virtual returns (IVault);

    function approveVault(IERC20 token, uint256 amount) public virtual;

    function _pullToken(
        address sender,
        IERC20 token,
        uint256 amount
    ) internal virtual;

    function _pullTokens(
        address sender,
        IERC20[] memory tokens,
        uint256[] memory amounts
    ) internal virtual;

    function _isChainedReference(uint256 amount) internal pure virtual returns (bool);

    function _setChainedReferenceValue(uint256 ref, uint256 value) internal virtual;

    function _getChainedReferenceValue(uint256 ref) internal virtual returns (uint256);
}
