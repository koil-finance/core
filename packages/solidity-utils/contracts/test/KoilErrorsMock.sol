// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../helpers/KoilErrors.sol";

contract KoilErrorsMock {
    function fail(uint256 code) external pure {
        _revert(code);
    }
}
