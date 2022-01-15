// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "../factories/BasePoolSplitCodeFactory.sol";
import "./MockFactoryCreatedPool.sol";

contract MockPoolSplitCodeFactory is BasePoolSplitCodeFactory {
    constructor(IVault _vault) BasePoolSplitCodeFactory(_vault, type(MockFactoryCreatedPool).creationCode) {
        // solhint-disable-previous-line no-empty-blocks
    }

    function create() external returns (address) {
        return _create("");
    }
}
