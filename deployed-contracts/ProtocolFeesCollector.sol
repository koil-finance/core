// File @koil-finance/solidity-utils/contracts/openzeppelin/IERC20.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma experimental ABIEncoderV2;
pragma solidity ^0.7.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File @koil-finance/solidity-utils/contracts/helpers/KoilErrors.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

// solhint-disable

/**
 * @dev Reverts if `condition` is false, with a revert reason containing `errorCode`. Only codes up to 999 are
 * supported.
 */
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}

/**
 * @dev Reverts with a revert reason containing `errorCode`. Only codes up to 999 are supported.
 */
function _revert(uint256 errorCode) pure {
    // We're going to dynamically create a revert string based on the error code, with the following format:
    // 'KOIL#{errorCode}'
    // where the code is left-padded with zeroes to three digits (so they range from 000 to 999).
    //
    // We don't have revert strings embedded in the contract to save bytecode size: it takes much less space to store a
    // number (8 to 16 bits) than the individual string characters.
    //
    // The dynamic string creation algorithm that follows could be implemented in Solidity, but assembly allows for a
    // much denser implementation, again saving bytecode size. Given this function unconditionally reverts, this is a
    // safe place to rely on it without worrying about how its usage might affect e.g. memory contents.
    assembly {
        // First, we need to compute the ASCII representation of the error code. We assume that it is in the 0-999
        // range, so we only need to convert three digits. To convert the digits to ASCII, we add 0x30, the value for
        // the '0' character.

        let units := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        // With the individual characters, we can now construct the full string. The "KOIL#" part is a known constant
        // (0x42414c23): we simply shift this by 24 (to provide space for the 3 bytes of the error code), and add the
        // characters to it, each shifted by a multiple of 8.
        // The revert reason is then shifted left by 200 bits (256 minus the length of the string, 7 characters * 8 bits
        // per character = 56) to locate it in the most significant part of the 256 slot (the beginning of a byte
        // array).

        let revertReason := shl(200, add(0x42414c23000000, add(add(units, shl(8, tenths)), shl(16, hundreds))))

        // We can now encode the reason in memory, which can be safely overwritten as we're about to revert. The encoded
        // message will have the following layout:
        // [ revert reason identifier ] [ string location offset ] [ string length ] [ string contents ]

        // The Solidity revert reason identifier is 0x08c739a0, the function selector of the Error(string) function. We
        // also write zeroes to the next 28 bytes of memory, but those are about to be overwritten.
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        // Next is the offset to the location of the string, which will be placed immediately after (20 bytes away).
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        // The string length is fixed: 7 characters.
        mstore(0x24, 7)
        // Finally, the string itself is stored.
        mstore(0x44, revertReason)

        // Even if the string is only 7 bytes long, we need to return a full 32 byte slot containing it. The length of
        // the encoded message is therefore 4 + 32 + 32 + 32 = 100.
        revert(0, 100)
    }
}

library Errors {
    // Math
    uint256 internal constant ADD_OVERFLOW = 0;
    uint256 internal constant SUB_OVERFLOW = 1;
    uint256 internal constant SUB_UNDERFLOW = 2;
    uint256 internal constant MUL_OVERFLOW = 3;
    uint256 internal constant ZERO_DIVISION = 4;
    uint256 internal constant DIV_INTERNAL = 5;
    uint256 internal constant X_OUT_OF_BOUNDS = 6;
    uint256 internal constant Y_OUT_OF_BOUNDS = 7;
    uint256 internal constant PRODUCT_OUT_OF_BOUNDS = 8;
    uint256 internal constant INVALID_EXPONENT = 9;

    // Input
    uint256 internal constant OUT_OF_BOUNDS = 100;
    uint256 internal constant UNSORTED_ARRAY = 101;
    uint256 internal constant UNSORTED_TOKENS = 102;
    uint256 internal constant INPUT_LENGTH_MISMATCH = 103;
    uint256 internal constant ZERO_TOKEN = 104;

    // Shared pools
    uint256 internal constant MIN_TOKENS = 200;
    uint256 internal constant MAX_TOKENS = 201;
    uint256 internal constant MAX_SWAP_FEE_PERCENTAGE = 202;
    uint256 internal constant MIN_SWAP_FEE_PERCENTAGE = 203;
    uint256 internal constant MINIMUM_KPT = 204;
    uint256 internal constant CALLER_NOT_VAULT = 205;
    uint256 internal constant UNINITIALIZED = 206;
    uint256 internal constant KPT_IN_MAX_AMOUNT = 207;
    uint256 internal constant KPT_OUT_MIN_AMOUNT = 208;
    uint256 internal constant EXPIRED_PERMIT = 209;
    uint256 internal constant NOT_TWO_TOKENS = 210;

    // Pools
    uint256 internal constant MIN_AMP = 300;
    uint256 internal constant MAX_AMP = 301;
    uint256 internal constant MIN_WEIGHT = 302;
    uint256 internal constant MAX_STABLE_TOKENS = 303;
    uint256 internal constant MAX_IN_RATIO = 304;
    uint256 internal constant MAX_OUT_RATIO = 305;
    uint256 internal constant MIN_KPT_IN_FOR_TOKEN_OUT = 306;
    uint256 internal constant MAX_OUT_KPT_FOR_TOKEN_IN = 307;
    uint256 internal constant NORMALIZED_WEIGHT_INVARIANT = 308;
    uint256 internal constant INVALID_TOKEN = 309;
    uint256 internal constant UNHANDLED_JOIN_KIND = 310;
    uint256 internal constant ZERO_INVARIANT = 311;
    uint256 internal constant ORACLE_INVALID_SECONDS_QUERY = 312;
    uint256 internal constant ORACLE_NOT_INITIALIZED = 313;
    uint256 internal constant ORACLE_QUERY_TOO_OLD = 314;
    uint256 internal constant ORACLE_INVALID_INDEX = 315;
    uint256 internal constant ORACLE_BAD_SECS = 316;
    uint256 internal constant AMP_END_TIME_TOO_CLOSE = 317;
    uint256 internal constant AMP_ONGOING_UPDATE = 318;
    uint256 internal constant AMP_RATE_TOO_HIGH = 319;
    uint256 internal constant AMP_NO_ONGOING_UPDATE = 320;
    uint256 internal constant STABLE_INVARIANT_DIDNT_CONVERGE = 321;
    uint256 internal constant STABLE_GET_BALANCE_DIDNT_CONVERGE = 322;
    uint256 internal constant RELAYER_NOT_CONTRACT = 323;
    uint256 internal constant BASE_POOL_RELAYER_NOT_CALLED = 324;
    uint256 internal constant REBALANCING_RELAYER_REENTERED = 325;
    uint256 internal constant GRADUAL_UPDATE_TIME_TRAVEL = 326;
    uint256 internal constant SWAPS_DISABLED = 327;
    uint256 internal constant CALLER_IS_NOT_LBP_OWNER = 328;
    uint256 internal constant PRICE_RATE_OVERFLOW = 329;
    uint256 internal constant INVALID_JOIN_EXIT_KIND_WHILE_SWAPS_DISABLED = 330;
    uint256 internal constant WEIGHT_CHANGE_TOO_FAST = 331;
    uint256 internal constant LOWER_GREATER_THAN_UPPER_TARGET = 332;
    uint256 internal constant UPPER_TARGET_TOO_HIGH = 333;
    uint256 internal constant UNHANDLED_BY_LINEAR_POOL = 334;
    uint256 internal constant OUT_OF_TARGET_RANGE = 335;
    uint256 internal constant UNHANDLED_EXIT_KIND = 336;
    uint256 internal constant UNAUTHORIZED_EXIT = 337;
    uint256 internal constant MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE = 338;
    uint256 internal constant UNHANDLED_BY_MANAGED_POOL = 339;
    uint256 internal constant UNHANDLED_BY_PHANTOM_POOL = 340;
    uint256 internal constant TOKEN_DOES_NOT_HAVE_RATE_PROVIDER = 341;
    uint256 internal constant INVALID_INITIALIZATION = 342;
    uint256 internal constant OUT_OF_NEW_TARGET_RANGE = 343;
    uint256 internal constant UNAUTHORIZED_OPERATION = 344;
    uint256 internal constant UNINITIALIZED_POOL_CONTROLLER = 345;

    // Lib
    uint256 internal constant REENTRANCY = 400;
    uint256 internal constant SENDER_NOT_ALLOWED = 401;
    uint256 internal constant PAUSED = 402;
    uint256 internal constant PAUSE_WINDOW_EXPIRED = 403;
    uint256 internal constant MAX_PAUSE_WINDOW_DURATION = 404;
    uint256 internal constant MAX_BUFFER_PERIOD_DURATION = 405;
    uint256 internal constant INSUFFICIENT_BALANCE = 406;
    uint256 internal constant INSUFFICIENT_ALLOWANCE = 407;
    uint256 internal constant ERC20_TRANSFER_FROM_ZERO_ADDRESS = 408;
    uint256 internal constant ERC20_TRANSFER_TO_ZERO_ADDRESS = 409;
    uint256 internal constant ERC20_MINT_TO_ZERO_ADDRESS = 410;
    uint256 internal constant ERC20_BURN_FROM_ZERO_ADDRESS = 411;
    uint256 internal constant ERC20_APPROVE_FROM_ZERO_ADDRESS = 412;
    uint256 internal constant ERC20_APPROVE_TO_ZERO_ADDRESS = 413;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_ALLOWANCE = 414;
    uint256 internal constant ERC20_DECREASED_ALLOWANCE_BELOW_ZERO = 415;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_BALANCE = 416;
    uint256 internal constant ERC20_BURN_EXCEEDS_ALLOWANCE = 417;
    uint256 internal constant SAFE_ERC20_CALL_FAILED = 418;
    uint256 internal constant ADDRESS_INSUFFICIENT_BALANCE = 419;
    uint256 internal constant ADDRESS_CANNOT_SEND_VALUE = 420;
    uint256 internal constant SAFE_CAST_VALUE_CANT_FIT_INT256 = 421;
    uint256 internal constant GRANT_SENDER_NOT_ADMIN = 422;
    uint256 internal constant REVOKE_SENDER_NOT_ADMIN = 423;
    uint256 internal constant RENOUNCE_SENDER_NOT_ALLOWED = 424;
    uint256 internal constant BUFFER_PERIOD_EXPIRED = 425;
    uint256 internal constant CALLER_IS_NOT_OWNER = 426;
    uint256 internal constant NEW_OWNER_IS_ZERO = 427;
    uint256 internal constant CODE_DEPLOYMENT_FAILED = 428;
    uint256 internal constant CALL_TO_NON_CONTRACT = 429;
    uint256 internal constant LOW_LEVEL_CALL_FAILED = 430;
    uint256 internal constant NOT_PAUSED = 431;
    uint256 internal constant ADDRESS_ALREADY_ALLOWLISTED = 432;
    uint256 internal constant ADDRESS_NOT_ALLOWLISTED = 433;

    // Vault
    uint256 internal constant INVALID_POOL_ID = 500;
    uint256 internal constant CALLER_NOT_POOL = 501;
    uint256 internal constant SENDER_NOT_ASSET_MANAGER = 502;
    uint256 internal constant USER_DOESNT_ALLOW_RELAYER = 503;
    uint256 internal constant INVALID_SIGNATURE = 504;
    uint256 internal constant EXIT_BELOW_MIN = 505;
    uint256 internal constant JOIN_ABOVE_MAX = 506;
    uint256 internal constant SWAP_LIMIT = 507;
    uint256 internal constant SWAP_DEADLINE = 508;
    uint256 internal constant CANNOT_SWAP_SAME_TOKEN = 509;
    uint256 internal constant UNKNOWN_AMOUNT_IN_FIRST_SWAP = 510;
    uint256 internal constant MALCONSTRUCTED_MULTIHOP_SWAP = 511;
    uint256 internal constant INTERNAL_BALANCE_OVERFLOW = 512;
    uint256 internal constant INSUFFICIENT_INTERNAL_BALANCE = 513;
    uint256 internal constant INVALID_FUSE_INTERNAL_BALANCE = 514;
    uint256 internal constant INVALID_POST_LOAN_BALANCE = 515;
    uint256 internal constant INSUFFICIENT_FUSE = 516;
    uint256 internal constant UNALLOCATED_FUSE = 517;
    uint256 internal constant FUSE_TRANSFER = 518;
    uint256 internal constant CANNOT_USE_FUSE_SENTINEL = 519;
    uint256 internal constant TOKENS_MISMATCH = 520;
    uint256 internal constant TOKEN_NOT_REGISTERED = 521;
    uint256 internal constant TOKEN_ALREADY_REGISTERED = 522;
    uint256 internal constant TOKENS_ALREADY_SET = 523;
    uint256 internal constant TOKENS_LENGTH_MUST_BE_2 = 524;
    uint256 internal constant NONZERO_TOKEN_BALANCE = 525;
    uint256 internal constant BALANCE_TOTAL_OVERFLOW = 526;
    uint256 internal constant POOL_NO_TOKENS = 527;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_BALANCE = 528;

    // Fees
    uint256 internal constant SWAP_FEE_PERCENTAGE_TOO_HIGH = 600;
    uint256 internal constant FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH = 601;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT = 602;
}


// File @koil-finance/solidity-utils/contracts/helpers/InputHelpers.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

library InputHelpers {
    function ensureInputLengthMatch(uint256 a, uint256 b) internal pure {
        _require(a == b, Errors.INPUT_LENGTH_MISMATCH);
    }

    function ensureInputLengthMatch(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure {
        _require(a == b && b == c, Errors.INPUT_LENGTH_MISMATCH);
    }

    function ensureArrayIsSorted(IERC20[] memory array) internal pure {
        address[] memory addressArray;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addressArray := array
        }
        ensureArrayIsSorted(addressArray);
    }

    function ensureArrayIsSorted(address[] memory array) internal pure {
        if (array.length < 2) {
            return;
        }

        address previous = array[0];
        for (uint256 i = 1; i < array.length; ++i) {
            address current = array[i];
            _require(previous < current, Errors.UNSORTED_ARRAY);
            previous = current;
        }
    }
}


// File @koil-finance/solidity-utils/contracts/helpers/IAuthentication.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

interface IAuthentication {
    /**
     * @dev Returns the action identifier associated with the external function described by `selector`.
     */
    function getActionId(bytes4 selector) external view returns (bytes32);
}


// File @koil-finance/solidity-utils/contracts/helpers/Authentication.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;


/**
 * @dev Building block for performing access control on external functions.
 *
 * This contract is used via the `authenticate` modifier (or the `_authenticateCaller` function), which can be applied
 * to external functions to only make them callable by authorized accounts.
 *
 * Derived contracts must implement the `_canPerform` function, which holds the actual access control logic.
 */
abstract contract Authentication is IAuthentication {
    bytes32 private immutable _actionIdDisambiguator;

    /**
     * @dev The main purpose of the `actionIdDisambiguator` is to prevent accidental function selector collisions in
     * multi contract systems.
     *
     * There are two main uses for it:
     *  - if the contract is a singleton, any unique identifier can be used to make the associated action identifiers
     *    unique. The contract's own address is a good option.
     *  - if the contract belongs to a family that shares action identifiers for the same functions, an identifier
     *    shared by the entire family (and no other contract) should be used instead.
     */
    constructor(bytes32 actionIdDisambiguator) {
        _actionIdDisambiguator = actionIdDisambiguator;
    }

    /**
     * @dev Reverts unless the caller is allowed to call this function. Should only be applied to external functions.
     */
    modifier authenticate() {
        _authenticateCaller();
        _;
    }

    /**
     * @dev Reverts unless the caller is allowed to call the entry point function.
     */
    function _authenticateCaller() internal view {
        bytes32 actionId = getActionId(msg.sig);
        _require(_canPerform(actionId, msg.sender), Errors.SENDER_NOT_ALLOWED);
    }

    function getActionId(bytes4 selector) public view override returns (bytes32) {
        // Each external function is dynamically assigned an action identifier as the hash of the disambiguator and the
        // function selector. Disambiguation is necessary to avoid potential collisions in the function selectors of
        // multiple contracts.
        return keccak256(abi.encodePacked(_actionIdDisambiguator, selector));
    }

    function _canPerform(bytes32 actionId, address user) internal view virtual returns (bool);
}


// File @koil-finance/solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

// Based on the ReentrancyGuard library from OpenZeppelin Contracts, altered to reduce bytecode size.
// Modifier code is inlined by the compiler, which causes its code to appear multiple times in the codebase. By using
// private functions, we achieve the same end result with slightly higher runtime gas costs, but reduced bytecode size.

pragma solidity ^0.7.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256[] private _statusMapping = new uint256[](2);

    constructor() {}

    modifier nonReentrant(uint256 purpose) {
        _enterNonReentrant(purpose);
        _;
        _exitNonReentrant(purpose);
    }

    function _enterNonReentrant(uint256 purpose) private {
        // On the first call to nonReentrant, status will be undefined
        _require(_statusMapping[purpose] != _ENTERED, Errors.REENTRANCY);

        // Any calls to nonReentrant after this point will fail
        _statusMapping[purpose] = _ENTERED;
    }

    function _exitNonReentrant(uint256 purpose) private {
        _statusMapping[purpose] = _NOT_ENTERED;
    }
}


// File @koil-finance/solidity-utils/contracts/openzeppelin/SafeERC20.sol@v1.0.1

// SPDX!-License-Identifier: GPL-3.0-or-later

// Based on the ReentrancyGuard library from OpenZeppelin Contracts, altered to reduce gas costs.
// The `safeTransfer` and `safeTransferFrom` functions assume that `token` is a contract (an account with code), and
// work differently from the OpenZeppelin version if it is not.

pragma solidity ^0.7.0;

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     *
     * WARNING: `token` is assumed to be a contract: calls to EOAs will *not* revert.
     */
    function _callOptionalReturn(address token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.
        (bool success, bytes memory returndata) = token.call(data);

        // If the low-level call didn't succeed we return whatever was returned from it.
        assembly {
            if eq(success, 0) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Finally we check the returndata size is either zero or true - note that this check will always pass for EOAs
        _require(returndata.length == 0 || abi.decode(returndata, (bool)), Errors.SAFE_ERC20_CALL_FAILED);
    }
}


// File contracts/interfaces/IAuthorizer.sol

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

interface IAuthorizer {
    /**
     * @dev Returns true if `account` can perform the action described by `actionId` in the contract `where`.
     */
    function canPerform(
        bytes32 actionId,
        address account,
        address where
    ) external view returns (bool);
}


// File contracts/interfaces/IVaultPartial.sol

// SPDX!-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;

interface IVaultPartial {
    /**
     * @dev Returns the Vault's Authorizer.
     */
    function getAuthorizer() external view returns (IAuthorizer);

    /**
     * @dev Sets a new Authorizer for the Vault. The caller must be allowed by the current Authorizer to do this.
     *
     * Emits an `AuthorizerChanged` event.
     */
    function setAuthorizer(IAuthorizer newAuthorizer) external;

    /**
     * @dev Emitted when a new authorizer is set by `setAuthorizer`.
     */
    event AuthorizerChanged(IAuthorizer indexed newAuthorizer);
}


// File contracts/interfaces/IProtocolFeesCollector.sol

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;


interface IProtocolFeesCollector {
    event SwapFeePercentageChanged(uint256 newSwapFeePercentage);
    event FlashLoanFeePercentageChanged(uint256 newFlashLoanFeePercentage);

    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external;

    function setSwapFeePercentage(uint256 newSwapFeePercentage) external;

    function setFlashLoanFeePercentage(uint256 newFlashLoanFeePercentage) external;

    function getSwapFeePercentage() external view returns (uint256);

    function getFlashLoanFeePercentage() external view returns (uint256);

    function getCollectedFeeAmounts(IERC20[] memory tokens) external view returns (uint256[] memory feeAmounts);

    function getAuthorizer() external view returns (IAuthorizer);

    function vault() external view returns (IVaultPartial);
}


// File contracts/ProtocolFeesCollector.sol

// SPDX!-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;




/**
 * @dev This an auxiliary contract to the Vault, deployed by it during construction. It offloads some of the tasks the
 * Vault performs to reduce its overall bytecode size.
 *
 * The current values for all protocol fee percentages are stored here, and any tokens charged as protocol fees are
 * sent to this contract, where they may be withdrawn by authorized entities. All authorization tasks are delegated
 * to the Vault's own authorizer.
 */
contract ProtocolFeesCollector is IProtocolFeesCollector, Authentication, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Absolute maximum fee percentages (1e18 = 100%, 1e16 = 1%).
    uint256 private constant _MAX_PROTOCOL_SWAP_FEE_PERCENTAGE = 50e16; // 50%
    uint256 private constant _MAX_PROTOCOL_FLASH_LOAN_FEE_PERCENTAGE = 1e16; // 1%

    IVaultPartial public immutable override vault;

    // All fee percentages are 18-decimal fixed point numbers.

    // The swap fee is charged whenever a swap occurs, as a percentage of the fee charged by the Pool. These are not
    // actually charged on each individual swap: the `Vault` relies on the Pools being honest and reporting fees due
    // when users join and exit them.
    uint256 private _swapFeePercentage;

    // The flash loan fee is charged whenever a flash loan occurs, as a percentage of the tokens lent.
    uint256 private _flashLoanFeePercentage;

    constructor(IVaultPartial _vault)
        // The ProtocolFeesCollector is a singleton, so it simply uses its own address to disambiguate action
        // identifiers.
        Authentication(bytes32(uint256(address(this))))
    {
        vault = _vault;
    }

    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external override nonReentrant(0) authenticate {
        InputHelpers.ensureInputLengthMatch(tokens.length, amounts.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];
            token.safeTransfer(recipient, amount);
        }
    }

    function setSwapFeePercentage(uint256 newSwapFeePercentage) external override authenticate {
        _require(newSwapFeePercentage <= _MAX_PROTOCOL_SWAP_FEE_PERCENTAGE, Errors.SWAP_FEE_PERCENTAGE_TOO_HIGH);
        _swapFeePercentage = newSwapFeePercentage;
        emit SwapFeePercentageChanged(newSwapFeePercentage);
    }

    function setFlashLoanFeePercentage(uint256 newFlashLoanFeePercentage) external override authenticate {
        _require(
            newFlashLoanFeePercentage <= _MAX_PROTOCOL_FLASH_LOAN_FEE_PERCENTAGE,
            Errors.FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH
        );
        _flashLoanFeePercentage = newFlashLoanFeePercentage;
        emit FlashLoanFeePercentageChanged(newFlashLoanFeePercentage);
    }

    function getSwapFeePercentage() external view override returns (uint256) {
        return _swapFeePercentage;
    }

    function getFlashLoanFeePercentage() external view override returns (uint256) {
        return _flashLoanFeePercentage;
    }

    function getCollectedFeeAmounts(IERC20[] memory tokens)
        external
        view
        override
        returns (uint256[] memory feeAmounts)
    {
        feeAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            feeAmounts[i] = tokens[i].balanceOf(address(this));
        }
    }

    function getAuthorizer() external view override returns (IAuthorizer) {
        return _getAuthorizer();
    }

    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }

    function _getAuthorizer() internal view returns (IAuthorizer) {
        return vault.getAuthorizer();
    }
}
