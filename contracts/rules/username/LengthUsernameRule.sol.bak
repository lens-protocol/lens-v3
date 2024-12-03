// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";

contract LengthUsernameRule is IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_MIN_LENGTH_PID = uint256(keccak256("SKIP_MIN_LENGTH"));
    uint256 constant SKIP_MAX_LENGTH_PID = uint256(keccak256("SKIP_MAX_LENGTH"));

    struct LengthRestrictions {
        uint8 min;
        uint8 max;
    }

    struct Configuration {
        address accessControl;
        LengthRestrictions lengthRestrictions;
    }

    mapping(address => Configuration) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_MIN_LENGTH_PID, "SKIP_MIN_LENGTH");
        emit Events.Lens_PermissionId_Available(SKIP_MAX_LENGTH_PID, "SKIP_MAX_LENGTH");
    }

    function configure(bytes calldata data) external {
        Configuration memory configuration = abi.decode(data, (Configuration));
        configuration.accessControl.verifyHasAccessFunction();
        require(
            configuration.lengthRestrictions.max == 0
                || configuration.lengthRestrictions.min <= configuration.lengthRestrictions.max
        ); // Min length cannot be greater than max length
        _configuration[msg.sender] = configuration;
    }

    function processCreation(
        address account,
        string calldata username,
        bytes calldata /* data */
    ) external view returns (bool) {
        Configuration memory configuration = _configuration[msg.sender];
        uint256 usernameLength = bytes(username).length;
        if (
            configuration.lengthRestrictions.min != 0
                && !configuration.accessControl.hasAccess(account, SKIP_MIN_LENGTH_PID)
        ) {
            require(usernameLength >= configuration.lengthRestrictions.min, "Username: too short");
        }
        if (
            configuration.lengthRestrictions.max != 0
                && !configuration.accessControl.hasAccess(account, SKIP_MAX_LENGTH_PID)
        ) {
            require(usernameLength <= configuration.lengthRestrictions.max, "Username: too long");
        }
        return true;
    }

    function processAssigning(
        address, /* account */
        string calldata, /* username */
        bytes calldata /* data */
    ) external pure returns (bool) {
        return false;
    }
}
