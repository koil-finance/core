// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/openzeppelin/ERC20.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/ERC20Burnable.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/ERC20Permit.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/AccessControl.sol";

contract TestToken is AccessControl, ERC20, ERC20Burnable, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol) ERC20Permit(name) {
        _setupDecimals(decimals);
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, admin);
    }

    function mint(address recipient, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender, address(this)), "NOT_MINTER");
        _mint(recipient, amount);
    }
}
