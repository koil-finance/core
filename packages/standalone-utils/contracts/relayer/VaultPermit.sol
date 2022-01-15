// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20Permit.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20PermitDAI.sol";
import "@koil-finance/vault/contracts/interfaces/IVault.sol";

import "../interfaces/IBaseRelayerLibrary.sol";

/**
 * @title VaultPermit
 * @notice Allows users to approve the Koil Vault to use their tokens using permit (where supported)
 * @dev All functions must be payable so that it can be called as part of a multicall involving FUSE
 */
abstract contract VaultPermit is IBaseRelayerLibrary {
    function vaultPermit(
        IERC20Permit token,
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        token.permit(owner, address(getVault()), value, deadline, v, r, s);
    }

    function vaultPermitDAI(
        IERC20PermitDAI token,
        address holder,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        token.permit(holder, address(getVault()), nonce, expiry, allowed, v, r, s);
    }
}
