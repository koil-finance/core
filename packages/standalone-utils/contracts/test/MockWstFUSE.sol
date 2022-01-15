// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "@koil-finance/solidity-utils/contracts/math/FixedPoint.sol";
import "@koil-finance/solidity-utils/contracts/openzeppelin/ERC20.sol";

import "../interfaces/IstFUSE.sol";
import "../interfaces/IwstFUSE.sol";

contract MockWstFUSE is ERC20, IwstFUSE {
    using FixedPoint for uint256;

    IstFUSE public override stFUSE;
    uint256 public rate = 1.5e18;

    constructor(IstFUSE token) ERC20("Wrapped Staked Fuse", "wstFUSE") {
        stFUSE = token;
    }

    function wrap(uint256 _stFUSEAmount) external override returns (uint256) {
        stFUSE.transferFrom(msg.sender, address(this), _stFUSEAmount);
        uint256 wstFUSEAmount = getWstFUSEByStFUSE(_stFUSEAmount);
        _mint(msg.sender, wstFUSEAmount);
        return wstFUSEAmount;
    }

    function unwrap(uint256 _wstFUSEAmount) external override returns (uint256) {
        _burn(msg.sender, _wstFUSEAmount);
        uint256 stFUSEAmount = getStFUSEByWstFUSE(_wstFUSEAmount);
        stFUSE.transfer(msg.sender, stFUSEAmount);
        return stFUSEAmount;
    }

    receive() external payable {
        stFUSE.submit{ value: msg.value }(address(this));
        _mint(msg.sender, getWstFUSEByStFUSE(msg.value));
    }

    function getWstFUSEByStFUSE(uint256 _stFUSEAmount) public view override returns (uint256) {
        return _stFUSEAmount.divDown(rate);
    }

    function getStFUSEByWstFUSE(uint256 _wstFUSEAmount) public view override returns (uint256) {
        return _wstFUSEAmount.mulDown(rate);
    }

    function stFusePerToken() external view override returns (uint256) {
        return getStFUSEByWstFUSE(1 ether);
    }

    function tokensPerStFuse() external view override returns (uint256) {
        return getWstFUSEByStFUSE(1 ether);
    }
}
