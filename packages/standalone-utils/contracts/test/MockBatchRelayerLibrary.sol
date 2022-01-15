// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../BatchRelayerLibrary.sol";

contract MockBatchRelayerLibrary is BatchRelayerLibrary {
    event ChainedReferenceValueRead(uint256 value);

    constructor(IVault vault, IERC20 wstFUSE) BatchRelayerLibrary(vault, wstFUSE) {}

    function setChainedReferenceValue(uint256 ref, uint256 value) public returns (uint256) {
        _setChainedReferenceValue(ref, value);
    }

    function getChainedReferenceValue(uint256 ref) public {
        emit ChainedReferenceValueRead(_getChainedReferenceValue(ref));
    }
}
