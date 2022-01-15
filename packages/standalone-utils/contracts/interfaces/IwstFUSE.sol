// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20.sol";

import "./IstFUSE.sol";

// solhint-disable-next-line max-line-length
// Based on https://github.com/lidofinance/lido-dao/blob/2b46615a11dee77d4d22066f942f6c6afab9b87a/contracts/0.6.12/WstFUSE.sol

/**
 * @title StFUSE token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of stFUSE tokens. WstFUSE token's balance only changes on transfers,
 * unlike StFUSE that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts stFUSE tokens and mints
 * wstFUSE in return. Then the user unwraps, the contract burns user's wstFUSE
 * and sends user locked stFUSE in return.
 *
 * The contract provides the staking shortcut: user can send FUSE with regular
 * transfer and get wstFUSE in return. The contract will send FUSE to Lido submit
 * method, staking it and wrapping the received stFUSE.
 *
 */
interface IwstFUSE is IERC20 {
    function stFUSE() external returns (IstFUSE);

    /**
     * @notice Exchanges stFUSE to wstFUSE
     * @param _stFUSEAmount amount of stFUSE to wrap in exchange for wstFUSE
     * @dev Requirements:
     *  - `_stFUSEAmount` must be non-zero
     *  - msg.sender must approve at least `_stFUSEAmount` stFUSE to this
     *    contract.
     *  - msg.sender must have at least `_stFUSEAmount` of stFUSE.
     * User should first approve _stFUSEAmount to the WstFUSE contract
     * @return Amount of wstFUSE user receives after wrap
     */
    function wrap(uint256 _stFUSEAmount) external returns (uint256);

    /**
     * @notice Exchanges wstFUSE to stFUSE
     * @param _wstFUSEAmount amount of wstFUSE to uwrap in exchange for stFUSE
     * @dev Requirements:
     *  - `_wstFUSEAmount` must be non-zero
     *  - msg.sender must have at least `_wstFUSEAmount` wstFUSE.
     * @return Amount of stFUSE user receives after unwrap
     */
    function unwrap(uint256 _wstFUSEAmount) external returns (uint256);

    /**
     * @notice Get amount of wstFUSE for a given amount of stFUSE
     * @param _stFUSEAmount amount of stFUSE
     * @return Amount of wstFUSE for a given stFUSE amount
     */
    function getWstFUSEByStFUSE(uint256 _stFUSEAmount) external view returns (uint256);

    /**
     * @notice Get amount of stFUSE for a given amount of wstFUSE
     * @param _wstFUSEAmount amount of wstFUSE
     * @return Amount of stFUSE for a given wstFUSE amount
     */
    function getStFUSEByWstFUSE(uint256 _wstFUSEAmount) external view returns (uint256);

    /**
     * @notice Get amount of wstFUSE for a one stFUSE
     * @return Amount of stFUSE for 1 wstFUSE
     */
    function stFusePerToken() external view returns (uint256);

    /**
     * @notice Get amount of stFUSE for a one wstFUSE
     * @return Amount of wstFUSE for a 1 stFUSE
     */
    function tokensPerStFuse() external view returns (uint256);
}
