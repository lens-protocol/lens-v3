// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "./../../core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {MetadataBased} from "./../../core/base/MetadataBased.sol";

contract UsernameCharsetNamespaceRule is INamespaceRule, MetadataBased {
    event Lens_Rule_MetadataURISet(string metadataURI);

    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    string constant UNRESTRICTED = "";

    // uint256(keccak256("SKIP_CHARSET"))
    uint256 immutable SKIP_CHARSET_PID = uint256(0xdcdf9b745e3f53451b2b79d265c8b66498f6483b3ef60fb5eb21c88e5f071211);

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.allowNumeric");
    bytes32 immutable ALLOW_NUMERIC_PARAM_KEY = 0xa5343d1f72fad751af812c7d2f314beb3946101f8926b126c90bf56185650e66;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.allowLatinLowercase");
    bytes32 immutable ALLOW_LATIN_LOWERCASE_PARAM_KEY =
        0x48000ae8df8d4602963f7fd9813736c2ad0dfa204db72c382d7763bdca24627d;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.allowLatinUppercase");
    bytes32 immutable ALLOW_LATIN_UPPERCASE_PARAM_KEY =
        0x3c19617bbf30f545edfbdfba272a5fa1896d806d87b89ef7b1bb6ea891fb2d79;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.customAllowedCharset");
    bytes32 immutable CUSTOM_ALLOWED_CHARSET_PARAM_KEY =
        0xe6cd53e810eb73a4469a94a3ec25b5568c19ca256303d99b5a025f8d1cd515cb;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.customDisallowedCharset");
    bytes32 immutable CUSTOM_DISALLOWED_CHARSET_PARAM_KEY =
        0x7b2d46fead0a26f8c7a25e0f4a26a6cfd344f33be50d92fbb3b617b9ed829c85;
    // keccak256("lens.rules.namespace.UsernameCharsetNamespaceRule.param.key.CharsetRestrictions.cannotStartWith");
    bytes32 immutable CANNOT_START_WITH_PARAM_KEY = 0xdb553ed6f7565512034b5c85634ef06a1666dc287f38cea87762d44684df1256;

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

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
        emit Events.Lens_PermissionId_Available(SKIP_CHARSET_PID, "SKIP_CHARSET");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
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
    ) external view override {
        Configuration memory configuration = _configuration[msg.sender][configSalt];
        if (!configuration.accessControl.hasAccess(originalMsgSender, SKIP_CHARSET_PID)) {
            _processRestrictions(username, configuration.charsetRestrictions);
        }
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function _processRestrictions(string calldata username, CharsetRestrictions memory charsetRestrictions)
        internal
        pure
    {
        // Cannot start with a character in the cannotStartWith charset
        require(
            !_isInCharset(bytes(username)[0], charsetRestrictions.cannotStartWith),
            "UsernameCharsetRule: Username cannot start with specified character"
        );
        // Check if the username contains only allowed characters
        for (uint256 i = 0; i < bytes(username).length; i++) {
            bytes1 char = bytes(username)[i];
            // Check disallowed chars first
            require(
                !_isInCharset(char, charsetRestrictions.customDisallowedCharset),
                "UsernameCharsetRule: Username contains disallowed character"
            );
            // Check allowed charsets next
            if (_isNumeric(char)) {
                require(charsetRestrictions.allowNumeric, "UsernameCharsetRule: Username cannot contain numbers");
            } else if (_isLatinLowercase(char)) {
                require(
                    charsetRestrictions.allowLatinLowercase,
                    "UsernameCharsetRule: Username cannot contain lowercase latin characters"
                );
            } else if (_isLatinUppercase(char)) {
                require(
                    charsetRestrictions.allowLatinUppercase,
                    "UsernameCharsetRule: Username cannot contain uppercase latin characters"
                );
            } else if (bytes(charsetRestrictions.customAllowedCharset).length > 0) {
                require(
                    _isInCharset(char, charsetRestrictions.customAllowedCharset),
                    "UsernameCharsetRule: Username contains disallowed character"
                );
            } else {
                // If not in any of the above charsets, reject
                revert("UsernameCharsetRule: Username contains disallowed character");
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
            if (params[i].key == ALLOW_NUMERIC_PARAM_KEY) {
                configuration.charsetRestrictions.allowNumeric = abi.decode(params[i].value, (bool));
            } else if (params[i].key == ALLOW_LATIN_LOWERCASE_PARAM_KEY) {
                configuration.charsetRestrictions.allowLatinLowercase = abi.decode(params[i].value, (bool));
            } else if (params[i].key == ALLOW_LATIN_UPPERCASE_PARAM_KEY) {
                configuration.charsetRestrictions.allowLatinUppercase = abi.decode(params[i].value, (bool));
            } else if (params[i].key == CUSTOM_ALLOWED_CHARSET_PARAM_KEY) {
                configuration.charsetRestrictions.customAllowedCharset = abi.decode(params[i].value, (string));
            } else if (params[i].key == CUSTOM_DISALLOWED_CHARSET_PARAM_KEY) {
                configuration.charsetRestrictions.customDisallowedCharset = abi.decode(params[i].value, (string));
            } else if (params[i].key == CANNOT_START_WITH_PARAM_KEY) {
                configuration.charsetRestrictions.cannotStartWith = abi.decode(params[i].value, (string));
            } else if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            }
        }
        return configuration;
    }
}
