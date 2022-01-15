// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@koil-finance/solidity-utils/contracts/misc/IWFUSE.sol";

import "./interfaces/IAsset.sol";

abstract contract AssetHelpers {
    // solhint-disable-next-line var-name-mixedcase
    IWFUSE private immutable _wfuse;

    // Sentinel value used to indicate WFUSE with wrapping/unwrapping semantics. The zero address is a good choice for
    // multiple reasons: it is cheap to pass as a calldata argument, it is a known invalid token and non-contract, and
    // it is an address Pools cannot register as a token.
    address private constant _FUSE = address(0);

    constructor(IWFUSE wfuse) {
        _wfuse = wfuse;
    }

    // solhint-disable-next-line func-name-mixedcase
    function _WFUSE() internal view returns (IWFUSE) {
        return _wfuse;
    }

    /**
     * @dev Returns true if `asset` is the sentinel value that represents FUSE.
     */
    function _isFUSE(IAsset asset) internal pure returns (bool) {
        return address(asset) == _FUSE;
    }

    /**
     * @dev Translates `asset` into an equivalent IERC20 token address.
     * If `asset` represents FUSE, it will be translated to the WFUSE contract.
     */
    function _translateToIERC20(IAsset asset) internal view returns (IERC20) {
        return _isFUSE(asset) ? _WFUSE() : _asIERC20(asset);
    }

    /**
     * @dev Same as `_translateToIERC20(IAsset)`, but for an entire array.
     */
    function _translateToIERC20(IAsset[] memory assets) internal view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            tokens[i] = _translateToIERC20(assets[i]);
        }
        return tokens;
    }

    /**
     * @dev Interprets `asset` as an IERC20 token.
     * This function should only be called on `asset` if `_isFUSE` previously returned false for it,
     * that is, if `asset` is guaranteed not to be the FUSE sentinel value.
     */
    function _asIERC20(IAsset asset) internal pure returns (IERC20) {
        return IERC20(address(asset));
    }
}
