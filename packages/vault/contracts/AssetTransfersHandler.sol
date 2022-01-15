// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@koil-finance/solidity-utils/contracts/math/Math.sol";
import "@koil-finance/solidity-utils/contracts/helpers/KoilErrors.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/Address.sol";
import "@koil-finance/solidity-utils/contracts/misc/IWFUSE.sol";

import "./interfaces/IAsset.sol";
import "./interfaces/IVault.sol";

import "./AssetHelpers.sol";

abstract contract AssetTransfersHandler is AssetHelpers {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /**
     * @dev Receives `amount` of `asset` from `sender`. If `fromInternalBalance` is true, it first withdraws as much
     * as possible from Internal Balance, then transfers any remaining amount.
     *
     * If `asset` is FUSE, `fromInternalBalance` must be false (as FUSE cannot be held as internal balance),
     * and the funds will be wrapped into WFUSE.
     *
     * WARNING: this function does not check that the contract caller has actually supplied any FUSE - it is up to the
     * caller of this function to check that this is true to prevent the Vault from using its own FUSE (though the Vault
     * typically doesn't hold any).
     */
    function _receiveAsset(
        IAsset asset,
        uint256 amount,
        address sender,
        bool fromInternalBalance
    ) internal {
        if (amount == 0) {
            return;
        }

        if (_isFUSE(asset)) {
            _require(!fromInternalBalance, Errors.INVALID_FUSE_INTERNAL_BALANCE);

            // The FUSE amount to receive is deposited into the WFUSE contract, which will in turn mint WFUSE for
            // the Vault at a 1:1 ratio.

            // A check for this condition is also introduced by the compiler, but this one provides a revert reason.
            // Note we're checking for the Vault's total balance, *not* FUSE sent in this transaction.
            _require(address(this).balance >= amount, Errors.INSUFFICIENT_FUSE);
            _WFUSE().deposit{ value: amount }();
        } else {
            IERC20 token = _asIERC20(asset);

            if (fromInternalBalance) {
                // We take as many tokens from Internal Balance as possible: any remaining amounts will be transferred.
                uint256 deductedBalance = _decreaseInternalBalance(sender, token, amount, true);
                // Because `deductedBalance` will be always the lesser of the current internal balance
                // and the amount to decrease, it is safe to perform unchecked arithmetic.
                amount -= deductedBalance;
            }

            if (amount > 0) {
                token.safeTransferFrom(sender, address(this), amount);
            }
        }
    }

    /**
     * @dev Sends `amount` of `asset` to `recipient`. If `toInternalBalance` is true, the asset is deposited as Internal
     * Balance instead of being transferred.
     *
     * If `asset` is FUSE, `toInternalBalance` must be false (as FUSE cannot be held as internal balance), and the funds
     * are instead sent directly after unwrapping WFUSE.
     */
    function _sendAsset(
        IAsset asset,
        uint256 amount,
        address payable recipient,
        bool toInternalBalance
    ) internal {
        if (amount == 0) {
            return;
        }

        if (_isFUSE(asset)) {
            // Sending FUSE is not as involved as receiving it: the only special behavior is it cannot be
            // deposited to Internal Balance.
            _require(!toInternalBalance, Errors.INVALID_FUSE_INTERNAL_BALANCE);

            // First, the Vault withdraws deposited FUSE from the WFUSE contract, by burning the same amount of WFUSE
            // from the Vault. This receipt will be handled by the Vault's `receive`.
            _WFUSE().withdraw(amount);

            // Then, the withdrawn FUSE is sent to the recipient.
            recipient.sendValue(amount);
        } else {
            IERC20 token = _asIERC20(asset);
            if (toInternalBalance) {
                _increaseInternalBalance(recipient, token, amount);
            } else {
                token.safeTransfer(recipient, amount);
            }
        }
    }

    /**
     * @dev Returns excess FUSE back to the contract caller, assuming `amountUsed` has been spent. Reverts
     * if the caller sent less FUSE than `amountUsed`.
     *
     * Because the caller might not know exactly how much FUSE a Vault action will require, they may send extra.
     * Note that this excess value is returned *to the contract caller* (msg.sender). If caller and e.g. swap sender are
     * not the same (because the caller is a relayer for the sender), then it is up to the caller to manage this
     * returned FUSE.
     */
    function _handleRemainingFuse(uint256 amountUsed) internal {
        _require(msg.value >= amountUsed, Errors.INSUFFICIENT_FUSE);

        uint256 excess = msg.value - amountUsed;
        if (excess > 0) {
            msg.sender.sendValue(excess);
        }
    }

    /**
     * @dev Enables the Vault to receive FUSE.
     * This is required for it to be able to unwrap WFUSE, which sends FUSE to the caller.
     *
     * Any FUSE sent to the Vault outside of the WFUSE unwrapping mechanism would be forever locked inside the Vault, so
     * we prevent that from happening. Other mechanisms used to send FUSE to the Vault (such as being the recipient of
     * an FUSE swap, Pool exit or withdrawal, contract self-destruction, or receiving the block mining reward) will
     * result in locked funds, but are not otherwise a security or soundness issue. This check only exists as an attempt
     * to prevent user error.
     */
    receive() external payable {
        _require(msg.sender == address(_WFUSE()), Errors.FUSE_TRANSFER);
    }

    // This contract uses virtual internal functions instead of inheriting from the modules that implement them (in
    // this case UserBalance) in order to decouple it from the rest of the system and enable standalone testing by
    // implementing these with mocks.

    function _increaseInternalBalance(
        address account,
        IERC20 token,
        uint256 amount
    ) internal virtual;

    function _decreaseInternalBalance(
        address account,
        IERC20 token,
        uint256 amount,
        bool capped
    ) internal virtual returns (uint256);
}
