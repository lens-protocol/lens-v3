// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";

contract TokenGatedUsernameRule is TokenGatedRule, IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_TOKEN_GATE_PID = uint256(keccak256("SKIP_TOKEN_GATE"));

    struct RestrictionConfiguration {
        bool restrictCreation;
        bool restrictAssigning;
    }

    struct Configuration {
        address accessControl;
        RestrictionConfiguration restrictions;
        TokenGateConfiguration tokenGate;
    }

    mapping(address => Configuration) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_TOKEN_GATE_PID, "SKIP_TOKEN_GATE");
    }

    function configure(bytes calldata data) external {
        Configuration memory configuration = abi.decode(data, (Configuration));
        configuration.accessControl.verifyHasAccessFunction();
        _validateTokenGateConfiguration(configuration.tokenGate);
        require(
            configuration.restrictions.restrictCreation || configuration.restrictions.restrictAssigning,
            "Username: no restrictions"
        );
        _configuration[msg.sender] = configuration;
    }

    function processCreation(
        address account,
        string calldata, /* username */
        bytes calldata /* data */
    ) external view returns (bool) {
        return _validateTokenBalance(
            _configuration[msg.sender].restrictions.restrictCreation,
            _configuration[msg.sender].accessControl,
            _configuration[msg.sender].tokenGate,
            account
        );
    }

    function processAssigning(
        address account,
        string calldata, /* username */
        bytes calldata /* data */
    ) external view returns (bool) {
        return _validateTokenBalance(
            _configuration[msg.sender].restrictions.restrictAssigning,
            _configuration[msg.sender].accessControl,
            _configuration[msg.sender].tokenGate,
            account
        );
    }

    function _validateTokenBalance(
        bool isRestricted,
        address accessControl,
        TokenGateConfiguration memory tokenGateConfiguration,
        address account
    ) internal view returns (bool) {
        if (isRestricted && !accessControl.hasAccess(account, SKIP_TOKEN_GATE_PID)) {
            _validateTokenBalance(tokenGateConfiguration, account);
        }
        return isRestricted;
    }
}
