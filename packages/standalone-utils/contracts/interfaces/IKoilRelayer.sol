// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/openzeppelin/Address.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";

import "@koil-finance/vault/contracts/interfaces/IVault.sol";

/**
 * @title IKoilRelayer
 * @notice Allows safe multicall execution of a relayer's functions
 */
interface IKoilRelayer {
    function getLibrary() external view returns (address);

    function getVault() external view returns (IVault);

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
