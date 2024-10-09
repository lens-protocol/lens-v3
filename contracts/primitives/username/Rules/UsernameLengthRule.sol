// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {IAccessControl} from "./../../access-control/IAccessControl.sol";
// import {IUsernameRule} from "./../IUsernameRule.sol";

// contract UsernameLengthRule is IUsernameRule {
//     uint256 _minLength; // "lens.username.rules.UsernameLengthRule.minLength"
//     uint256 _maxLength; // "lens.username.rules.UsernameLengthRule.maxLength"

//     IAccessControl internal _accessControl; // "lens.username.accessControl"

//     uint256 constant SKIP_MIN_LENGTH_RID = uint256(keccak256("SKIP_MIN_LENGTH"));
//     uint256 constant SKIP_MAX_LENGTH_RID = uint256(keccak256("SKIP_MAX_LENGTH"));

//     address immutable IMPLEMENTATION;

//     constructor() {
//         IMPLEMENTATION = address(this);
//     }

//     // TODO: We will write this assuming it's used only and JUST ONLY by the RuleCombinator.
//     // TODO: Do we want to support other 2 options (direct and non-combinator proxy) in our implementation?
//     function configure(bytes calldata data) external override {
//         require(address(this) != IMPLEMENTATION); // Cannot initialize implementation contract
//         (uint256 minLength, uint256 maxLength) = abi.decode(data, (uint256, uint256));
//         require(minLength > 0); // Empty username is not allowed
//         require(maxLength == 0 || minLength <= maxLength); // Min length cannot be greater than max length
//         _minLength = minLength;
//         _maxLength = maxLength; // maxLength = 0 means unlimited length
//     }

//     function processRegistering(address originalMsgSender, address, string memory username, bytes calldata)
//         external
//         view
//         override
//     {
//         uint256 usernameLength = bytes(username).length;
//         if (usernameLength < _minLength) {
//             require(
//                 _accessControl.hasAccess({
//                     account: originalMsgSender,
//                     resourceLocation: address(this),
//                     resourceId: SKIP_MIN_LENGTH_RID
//                 }),
//                 "UsernameLengthRule: cannot skip min length restriction"
//             );
//         }
//         if (_maxLength != 0 && usernameLength > _maxLength) {
//             require(
//                 _accessControl.hasAccess({
//                     account: originalMsgSender,
//                     resourceLocation: address(this),
//                     resourceId: SKIP_MAX_LENGTH_RID
//                 }),
//                 "UsernameLengthRule: cannot skip max length restriction"
//             );
//         }
//     }

//     function processUnregistering(address, address, string memory, bytes calldata) external pure override {}
// }
