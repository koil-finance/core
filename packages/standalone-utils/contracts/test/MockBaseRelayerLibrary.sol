// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../relayer/BaseRelayerLibrary.sol";

contract MockBaseRelayerLibrary is BaseRelayerLibrary {
    event ChainedReferenceValueRead(uint256 value);

    constructor(IVault vault) BaseRelayerLibrary(vault) {}

    function isChainedReference(uint256 amount) public pure returns (bool) {
        return _isChainedReference(amount);
    }

    function setChainedReferenceValue(uint256 ref, uint256 value) public returns (uint256) {
        _setChainedReferenceValue(ref, value);
    }

    function getChainedReferenceValue(uint256 ref) public {
        emit ChainedReferenceValueRead(_getChainedReferenceValue(ref));
    }
}
