// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";

contract CharsetUsernameRule is IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_CHARSET_PID = uint256(keccak256("SKIP_CHARSET"));

    struct CharsetRestrictions {
        bool allowNumeric;
        bool allowLatinLowercase;
        bool allowLatinUppercase;
        string customAllowedCharset; // Optional (pass empty string if not needed)
        string customDisallowedCharset; // Optional (pass empty string if not needed)
        string cannotStartWith; // Optional (pass empty string if not needed)
    }

    struct Configuration {
        address accessControl;
        CharsetRestrictions charsetRestrictions;
    }

    mapping(address => Configuration) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_CHARSET_PID, "SKIP_CHARSET");
    }

    function configure(bytes calldata data) external {
        Configuration memory configuration = abi.decode(data, (Configuration));
        configuration.accessControl.verifyHasAccessFunction();
        _configuration[msg.sender] = configuration;
    }

    function processCreation(
        address account,
        string calldata username,
        bytes calldata /* data*/
    ) external view returns (bool) {
        Configuration memory configuration = _configuration[msg.sender];
        if (!configuration.accessControl.hasAccess(account, SKIP_CHARSET_PID)) {
            _processRestrictions(username, configuration.charsetRestrictions);
        }
        return true;
    }

    function _processRestrictions(
        string calldata username,
        CharsetRestrictions memory charsetRestrictions
    ) internal pure {
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

    function processAssigning(
        address, /* account */
        string calldata, /* username */
        bytes calldata /* data */
    ) external pure returns (bool) {
        return false;
    }
}
