// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from './../../access-control/IAccessControl.sol';
import {IUsernameRules} from './../IUsernameRules.sol';

contract UsernameLengthRule is IUsernameRules {
    uint256 _minLength; // "lens.username.rules.UsernameLengthRule.minLength"
    uint256 _maxLength; // "lens.username.rules.UsernameLengthRule.maxLength"

    // TODO: This "_accessControl" address is not initliazed here because this is assumed being initialized in the combinator contract
    // and shared across all rules. We need to think about this, specially if this rule can be used standalone without a combinator too.
    //
    // But if somebody wants to have a specific per-rule accessControl - then they can use a local variable to store it.
    IAccessControl internal _accessControl; // "lens.username.accessControl"

    struct Permissions {
        bool canSetRolePermissions;
        bool canSkipMinLengthRestriction;
        bool canSkipMaxLengthRestriction;
    }

    mapping(uint256 => Permissions) _rolePermissions; // "lens.username.rules.UsernameLengthRule.rolePermissions"

    address immutable IMPLEMENTATION;

    constructor() {
        IMPLEMENTATION = address(this);
    }

    function setRolePermissions(
        uint256 role,
        bool canSetRolePermissions, // TODO: Think about this better
        bool canSkipMinLengthRestriction,
        bool canSkipMaxLengthRestriction
    ) external {
        require(_rolePermissions[_accessControl.getRole(msg.sender)].canSetRolePermissions); // Must have canSetRolePermissions
        _rolePermissions[role] = Permissions(
            canSetRolePermissions,
            canSkipMinLengthRestriction,
            canSkipMaxLengthRestriction
        );
    }

    function configure(bytes calldata data) external override {
        require(address(this) != IMPLEMENTATION); // Cannot initialize implementation contract
        (
            uint256 minLength,
            uint256 maxLength,
            uint256 ownerRoleId,
            bool canSetRolePermissions,
            bool canSkipMinLengthRestriction,
            bool canSkipMaxLengthRestriction
        ) = abi.decode(data, (uint256, uint256, uint256, bool, bool, bool));
        require(minLength <= maxLength); // Min length cannot be greater than max length
        _minLength = minLength;
        _maxLength = maxLength; // maxLength = 0 means unlimited length
        _rolePermissions[ownerRoleId] = Permissions(
            canSetRolePermissions,
            canSkipMinLengthRestriction,
            canSkipMaxLengthRestriction
        );
    }

    function processRegistering(
        address originalMsgSender,
        address,
        string memory username,
        bytes calldata
    ) external view override {
        uint256 usernameLength = bytes(username).length;
        if (usernameLength < _minLength) {
            require(_rolePermissions[_accessControl.getRole(originalMsgSender)].canSkipMinLengthRestriction);
        }
        if (_maxLength != 0 && usernameLength > _maxLength) {
            require(_rolePermissions[_accessControl.getRole(originalMsgSender)].canSkipMaxLengthRestriction);
        }
    }

    function processUnregistering(address, address, string memory, bytes calldata) external pure override {}
}
