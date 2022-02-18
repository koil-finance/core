// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/openzeppelin/Address.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";

import "../interfaces/IKoilRelayer.sol";

/**
 * @title Koil Relayer
 * @notice Allows safe multicall execution of a relayer's functions
 * @dev
 * Relayers are formed out of a system of two contracts:
 *  - This contract which acts as a single point of entry into the system through a multicall function
 *  - A library contract which defines the allowed behaviour of the relayer
 *
 * The relayer entrypoint can then repeatedly delegatecall into the library's code to perform actions.
 * We can then run combinations of the library contract's functions in the context of the relayer entrypoint
 * without having to expose all these functions on the entrypoint contract itself. The multicall function is
 * then a single point of entry for all actions which can be easily protected against reentrancy.
 *
 * This design gives much stronger reentrancy guarantees as otherwise a malicious contract could reenter
 * the relayer through another function (which must allow reentrancy for multicall logic) which would
 * potentially allow them to manipulate global state resulting in loss of funds in some cases.
 * e.g. sweeping any leftover FUSE which should have been refunded to the user.
 *
 * NOTE: Only the entrypoint contract should be whitelisted by Koil governance as a relayer and so the Vault
 * will reject calls made if they are not being run from within the context of the entrypoint.
 * e.g. in the case where a user mistakenly calls into the library contract directly.
 */
contract KoilRelayer is IKoilRelayer, ReentrancyGuard {
    using Address for address payable;
    using Address for address;

    IVault private immutable _vault;
    address private immutable _library;

    /**
     * @dev This contract is not meant to be deployed directly by an EOA, but rather during construction of a child of
     * `BaseRelayerLibrary` which will provides its own address to be used as the relayer's library.
     */
    constructor(IVault vault, address libraryAddress) {
        _vault = vault;
        _library = libraryAddress;
    }

    receive() external payable {
        // Accept FUSE transfers only coming from the Vault. This is expected to happen due to a swap/exit/withdrawal
        // with FUSE as an output should the relayer be listed as the recipient. This may also happen when
        // joining a pool, performing a swap or managing a user's balance does not use the full FUSE value provided.
        // Any excess FUSE value will be refunded back to this contract and forwarded back to the original sender.
        _require(msg.sender == address(_vault), Errors.FUSE_TRANSFER);
    }

    function getVault() external view override returns (IVault) {
        return _vault;
    }

    function getLibrary() external view override returns (address) {
        return _library;
    }

    function multicall(bytes[] calldata data) external payable override nonReentrant(0) returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = _library.functionDelegateCall(data[i]);
        }

        _refundFUSE();
    }

    function _refundFUSE() private {
        uint256 remainingFuse = address(this).balance;
        if (remainingFuse > 0) {
            msg.sender.sendValue(remainingFuse);
        }
    }
}
