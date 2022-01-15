// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "../factories/BasePoolFactory.sol";
import "./MockFactoryCreatedPool.sol";

contract MockPoolFactory is BasePoolFactory {
    constructor(IVault _vault) BasePoolFactory(_vault) {
        // solhint-disable-previous-line no-empty-blocks
    }

    function create() external returns (address) {
        address pool = address(new MockFactoryCreatedPool());
        _register(pool);
        return pool;
    }
}
