// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./relayer/BaseRelayerLibrary.sol";

import "./relayer/AaveWrapping.sol";
import "./relayer/LidoWrapping.sol";
import "./relayer/VaultActions.sol";
import "./relayer/VaultPermit.sol";

/**
 * @title Batch Relayer Library
 * @notice This contract is not a relayer by itself and calls into it directly will fail.
 * The associated relayer can be found by calling `getEntrypoint` on this contract.
 */
contract BatchRelayerLibrary is BaseRelayerLibrary, AaveWrapping, LidoWrapping, VaultActions, VaultPermit {
    constructor(IVault vault, IERC20 wstFUSE) BaseRelayerLibrary(vault) LidoWrapping(wstFUSE) {
        // solhint-disable-previous-line no-empty-blocks
    }
}
