// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20.sol";

// solhint-disable-next-line max-line-length
// Based on https://github.com/lidofinance/lido-dao/blob/816bf1d0995ba5cfdfc264de4acda34a7fe93eba/contracts/0.4.24/Lido.sol

interface IstFUSE is IERC20 {
    function submit(address referral) external payable returns (uint256);
}
