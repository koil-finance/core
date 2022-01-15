// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../openzeppelin/IERC20.sol";

/**
 * @dev Interface for WFUSE9.
 * See https://github.com/gnosis/canonical-wfuse/blob/0dd1ea3e295eef916d0c6223ec63141137d22d67/contracts/WFUSE9.sol
 */
interface IWFUSE is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
