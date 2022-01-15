// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./IControlledPool.sol";

interface IBasePoolController is IControlledPool {
    function initialize(address poolAddress) external;
}
