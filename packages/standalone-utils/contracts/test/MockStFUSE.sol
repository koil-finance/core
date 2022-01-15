// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/math/FixedPoint.sol";

import "./TestToken.sol";

import "../interfaces/IstFUSE.sol";

contract MockStFUSE is TestToken, IstFUSE {
    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) TestToken(admin, name, symbol, decimals) {
        // solhint-disable-previous-line no-empty-blocks
    }

    event FuseStaked(uint256 amount);

    function submit(address) external payable override returns (uint256) {
        _mint(msg.sender, msg.value);
        emit FuseStaked(msg.value);
        return msg.value;
    }
}
