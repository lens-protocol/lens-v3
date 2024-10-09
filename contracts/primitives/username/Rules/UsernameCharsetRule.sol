// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {IAccessControl} from "./../../access-control/IAccessControl.sol";
// import {IUsernameRule} from "./../IUsernameRule.sol";

// contract UsernameCharsetRule is IUsernameRule {
//     uint256 constant SKIP_CHARSET_RID = uint256(keccak256("SKIP_CHARSET"));
//     uint256 constant CHANGE_RULE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_RULE_ACCESS_CONTROL"));
//     uint256 constant CONFIGURE_RULE_RID = uint256(keccak256("CONFIGURE_RULE"));

//     struct CharsetRestrictions {
//         bool allowNumeric;
//         bool allowLatinLowercase;
//         bool allowLatinUppercase;
//         string customAllowedCharset; // Optional (pass empty string if not needed)
//         string customDisallowedCharset; // Optional (pass empty string if not needed)
//         string cannotStartWith; // Optional (pass empty string if not needed)
//     }

//     IAccessControl internal _accessControl; // "lens.username.accessControl"

//     CharsetRestrictions internal _charsetRestrictions;

//     address immutable IMPLEMENTATION;
//     bool internal _stateless;

//     // Provide accessControl to constructor if the rule is set directly
//     constructor(IAccessControl accessControl, bool stateless) {
//         IMPLEMENTATION = address(this);
//         // Initialize the access control.
//         // If this will be used with a proxy, pass stateless = true and accessControl = address(0).
//         _accessControl = accessControl;
//         _stateless = stateless;
//     }

//     function setAccessControl(address newAccessControl) external {
//         // Check if it's a direct implementation - then it should check if the msg.sender has a permission to SetAccessControl
//         _accessControl = IAccessControl(newAccessControl);
//     }

//     // We need this function in case this is used through a proxy (e.g. UUPS, Transparent or Beacon proxy).
//     function initiliaze(IAccessControl accessControl) external {
//         // TODO: This should be read from the "lens.username.accessControl" slot
//         require(address(_accessControl) == address(0), "UsernameCharsetRule: Already initialized");
//         _accessControl = accessControl;
//     }

//     // TODO: Is configure() allowed to be called directly? Or only from the Primitive?
//     // TODO: If yes - how do we check that it's a primitive?
//     // TODO: If we initialize the rule with some Primitive that only can call it - then we need to deploy a rule for every primitive? I thought these were singletons.
//     function configure(bytes calldata data) external override {
//         require(!_stateless); // Cannot configure implementation contract (no direct calls allowed, only delegateCall allowed)
//         (CharsetRestrictions memory newCharsetRestrictions, address accessControl) =
//             abi.decode(data, (CharsetRestrictions, address));

//         if (_differsFromCurrentRestrictions(newCharsetRestrictions)) {
//             require(
//                 _accessControl.hasAccess({
//                     account: msg.sender,
//                     resourceLocation: address(this),
//                     resourceId: CONFIGURE_RULE_RID
//                 })
//             ); // Must have can configure permission
//             _charsetRestrictions = newCharsetRestrictions;
//         }

//         if (accessControl != address(0)) {
//             require(
//                 _accessControl.hasAccess({
//                     account: msg.sender,
//                     resourceLocation: address(this),
//                     resourceId: CHANGE_RULE_ACCESS_CONTROL_RID
//                 })
//             ); // Must have canSetAccessControl
//             _accessControl = IAccessControl(accessControl);
//         }
//     }

//     function _differsFromCurrentRestrictions(CharsetRestrictions memory newRestrictions) internal view returns (bool) {
//         return keccak256(abi.encode(_charsetRestrictions)) != keccak256(abi.encode(newRestrictions));
//     }

//     function processRegistering(address originalMsgSender, address, string memory username, bytes calldata)
//         external
//         view
//         override
//     {
//         if (
//             _accessControl.hasAccess({
//                 account: originalMsgSender,
//                 resourceLocation: address(this),
//                 resourceId: SKIP_CHARSET_RID
//             })
//         ) {
//             return;
//         }
//         // Cannot start with a character in the cannotStartWith charset
//         require(
//             !_isInCharset(bytes(username)[0], _charsetRestrictions.cannotStartWith),
//             "UsernameCharsetRule: Username cannot start with specified character"
//         );
//         // Check if the username contains only allowed characters
//         for (uint256 i = 0; i < bytes(username).length; i++) {
//             bytes1 char = bytes(username)[i];
//             // Check disallowed chars first
//             require(
//                 !_isInCharset(char, _charsetRestrictions.customDisallowedCharset),
//                 "UsernameCharsetRule: Username contains disallowed character"
//             );

//             // Check allowed charsets next
//             if (_isNumeric(char)) {
//                 require(_charsetRestrictions.allowNumeric, "UsernameCharsetRule: Username cannot contain numbers");
//             } else if (_isLatinLowercase(char)) {
//                 require(
//                     _charsetRestrictions.allowLatinLowercase,
//                     "UsernameCharsetRule: Username cannot contain lowercase latin characters"
//                 );
//             } else if (_isLatinUppercase(char)) {
//                 require(
//                     _charsetRestrictions.allowLatinUppercase,
//                     "UsernameCharsetRule: Username cannot contain uppercase latin characters"
//                 );
//             } else if (bytes(_charsetRestrictions.customAllowedCharset).length > 0) {
//                 require(
//                     _isInCharset(char, _charsetRestrictions.customAllowedCharset),
//                     "UsernameCharsetRule: Username contains disallowed character"
//                 );
//             } else {
//                 // If not in any of the above charsets, reject
//                 revert("UsernameCharsetRule: Username contains disallowed character");
//             }
//         }
//     }

//     function processUnregistering(address, address, string memory, bytes calldata) external pure override {}

//     // Internal Charset Helper functions

//     /// @dev We only accept lowercase characters to avoid confusion.
//     /// @param char The character to check.
//     /// @return True if the character is alphanumeric, false otherwise.
//     function _isNumeric(bytes1 char) internal pure returns (bool) {
//         return (char >= "0" && char <= "9");
//     }

//     /// @dev We only accept lowercase characters to avoid confusion.
//     /// @param char The character to check.
//     /// @return True if the character is alphanumeric, false otherwise.
//     function _isLatinLowercase(bytes1 char) internal pure returns (bool) {
//         return (char >= "a" && char <= "z");
//     }

//     /// @dev We only accept lowercase characters to avoid confusion.
//     /// @param char The character to check.
//     /// @return True if the character is alphanumeric, false otherwise.
//     function _isLatinUppercase(bytes1 char) internal pure returns (bool) {
//         return (char >= "A" && char <= "Z");
//     }

//     function _isInCharset(bytes1 char, string memory charset) internal pure returns (bool) {
//         for (uint256 i = 0; i < bytes(charset).length; i++) {
//             if (char == bytes1(bytes(charset)[i])) {
//                 return true;
//             }
//         }
//         return false;
//     }
// }
