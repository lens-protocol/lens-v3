// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract UsernameCharsetNamespaceRule is INamespaceRule, OwnableMetadataBasedRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    string constant UNRESTRICTED = "";

    /// @custom:keccak lens.permission.SkipCharsetRestrictions
    uint256 constant PID__SKIP_CHARSET_RESTRICTIONS =
        uint256(0xe80b6488cb28aed0341cef6acc8d785449927ff75edf083fd1d3ea3f4883e6fe);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.allowNumeric
    bytes32 constant PARAM__ALLOW_NUMERIC = 0x9c767af33c504d4a59ff2622822d51b5ef43021074382f2ff27b2105d90a8e51;
    /// @custom:keccak lens.param.allowLatinLowercase
    bytes32 constant PARAM__ALLOW_LATIN_LOWERCASE = 0x54237b94f122fc08ecf50ce7b4b70024372a8be4b1f7e2c402e74fda43b74c7f;
    /// @custom:keccak lens.param.allowLatinUppercase
    bytes32 constant PARAM__ALLOW_LATIN_UPPERCASE = 0xcfec96cd369714d0ab6f715eb77b0dae9d8ad1c42c6f223391dd5ee0aa825897;
    /// @custom:keccak lens.param.customAllowedCharset
    bytes32 constant PARAM__CUSTOM_ALLOWED_CHARSET = 0x1503890d3cb87494db3ea6506e81bb58da67e80d82c074f968bd71fa241ebdba;
    /// @custom:keccak lens.param.customDisallowedCharset
    bytes32 constant PARAM__CUSTOM_DISALLOWED_CHARSET =
        0xc5e90b4342e3e921a3af69f90937f6e20b0aa7a82c7adf6795ba002e8dc8a67f;
    /// @custom:keccak lens.param.cannotStartWith
    bytes32 constant PARAM__CANNOT_START_WITH = 0xc96b6ff1bcfa502b5659a89edeaeb9713e283a8f6090f5b1ac62692b78f5dce2;

    struct CharsetRestrictions {
        bool allowNumeric; /////////////// Default: true
        bool allowLatinLowercase; //////// Default: true
        bool allowLatinUppercase; //////// Default: true
        string customAllowedCharset; ///// Default: empty string (unrestricted)
        string customDisallowedCharset; // Default: empty string (unrestricted)
        string cannotStartWith; ////////// Default: empty string (unrestricted)
    }

    struct Configuration {
        address accessControl;
        CharsetRestrictions charsetRestrictions;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(
            PID__SKIP_CHARSET_RESTRICTIONS, "lens.permission.SkipCharsetRestrictions"
        );
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external payable override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external payable override {
        Configuration memory configuration = _configuration[msg.sender][configSalt];
        if (!configuration.accessControl.hasAccess(originalMsgSender, PID__SKIP_CHARSET_RESTRICTIONS)) {
            _processRestrictions(username, configuration.charsetRestrictions);
        }
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external payable override {
        revert Errors.NotImplemented();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external payable override {
        revert Errors.NotImplemented();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external payable override {
        revert Errors.NotImplemented();
    }

    function _processRestrictions(string calldata username, CharsetRestrictions memory charsetRestrictions)
        internal
        pure
    {
        // Cannot start with a character in the cannotStartWith charset
        require(!_isInCharset(bytes(username)[0], charsetRestrictions.cannotStartWith), Errors.CannotStartWithThat());
        // Check if the username contains only allowed characters
        for (uint256 i = 0; i < bytes(username).length; i++) {
            bytes1 char = bytes(username)[i];
            // Check disallowed chars first
            require(!_isInCharset(char, charsetRestrictions.customDisallowedCharset), Errors.NotAllowed());
            // Check allowed charsets next
            if (_isNumeric(char)) {
                require(charsetRestrictions.allowNumeric, Errors.NotAllowed());
            } else if (_isLatinLowercase(char)) {
                require(charsetRestrictions.allowLatinLowercase, Errors.NotAllowed());
            } else if (_isLatinUppercase(char)) {
                require(charsetRestrictions.allowLatinUppercase, Errors.NotAllowed());
            } else if (bytes(charsetRestrictions.customAllowedCharset).length > 0) {
                require(_isInCharset(char, charsetRestrictions.customAllowedCharset), Errors.NotAllowed());
            } else {
                // If not in any of the above charsets, reject
                revert Errors.NotAllowed();
            }
        }
    }

    // Internal Charset Helper functions

    /// @dev We only accept lowercase characters to avoid confusion.
    /// @param char The character to check.
    /// @return True if the character is alphanumeric, false otherwise.
    function _isNumeric(bytes1 char) internal pure returns (bool) {
        return (char >= "0" && char <= "9");
    }

    /// @dev We only accept lowercase characters to avoid confusion.
    /// @param char The character to check.
    /// @return True if the character is alphanumeric, false otherwise.
    function _isLatinLowercase(bytes1 char) internal pure returns (bool) {
        return (char >= "a" && char <= "z");
    }

    /// @dev We only accept lowercase characters to avoid confusion.
    /// @param char The character to check.
    /// @return True if the character is alphanumeric, false otherwise.
    function _isLatinUppercase(bytes1 char) internal pure returns (bool) {
        return (char >= "A" && char <= "Z");
    }

    function _isInCharset(bytes1 char, string memory charset) internal pure returns (bool) {
        for (uint256 i = 0; i < bytes(charset).length; i++) {
            if (char == bytes1(bytes(charset)[i])) {
                return true;
            }
        }
        return false;
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        // Initialize configuration with default values
        configuration.charsetRestrictions = CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: true,
            customAllowedCharset: UNRESTRICTED,
            customDisallowedCharset: UNRESTRICTED,
            cannotStartWith: UNRESTRICTED
        });
        // Extract configuration from params
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ALLOW_NUMERIC) {
                configuration.charsetRestrictions.allowNumeric = abi.decode(params[i].value, (bool));
            } else if (params[i].key == PARAM__ALLOW_LATIN_LOWERCASE) {
                configuration.charsetRestrictions.allowLatinLowercase = abi.decode(params[i].value, (bool));
            } else if (params[i].key == PARAM__ALLOW_LATIN_UPPERCASE) {
                configuration.charsetRestrictions.allowLatinUppercase = abi.decode(params[i].value, (bool));
            } else if (params[i].key == PARAM__CUSTOM_ALLOWED_CHARSET) {
                configuration.charsetRestrictions.customAllowedCharset = abi.decode(params[i].value, (string));
            } else if (params[i].key == PARAM__CUSTOM_DISALLOWED_CHARSET) {
                configuration.charsetRestrictions.customDisallowedCharset = abi.decode(params[i].value, (string));
            } else if (params[i].key == PARAM__CANNOT_START_WITH) {
                configuration.charsetRestrictions.cannotStartWith = abi.decode(params[i].value, (string));
            } else if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            }
        }
        return configuration;
    }
}
