// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

contract FuseForceSender {
    constructor(address payable recipient) payable {
        selfdestruct(recipient);
    }
}
