// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "../KoilPoolToken.sol";

contract MockKoilPoolToken is KoilPoolToken {
    constructor(
        string memory name,
        string memory symbol,
        IVault vault
    ) KoilPoolToken(name, symbol, vault) {}

    function mint(address recipient, uint256 amount) external {
        _mintPoolTokens(recipient, amount);
    }

    function burn(address sender, uint256 amount) external {
        _burnPoolTokens(sender, amount);
    }
}
