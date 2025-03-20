// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {TokenGatedRule} from "contracts/rules/base/TokenGatedRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {Events} from "contracts/core/types/Events.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract TokenGatedFeedRule is TokenGatedRule, Initializable, IFeedRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipGate
    uint256 constant PID__SKIP_GATE = uint256(0xeb7f30e4c97d5211e2534aa42375c26931bd55b57a8101e5eb7918daead714eb);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    /// @custom:keccak lens.storage.TokenGatedFeedRule
    bytes32 constant STORAGE__TOKEN_GATED_FEED_RULE = 0xd05368ec51bd7f193185c9db5c15fb8de0f631a954507a483fb9bb1f567a00c9;

    struct Configuration {
        address accessControl;
        TokenGateConfiguration tokenGate;
    }

    struct Storage {
        mapping(address feed => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__TOKEN_GATED_FEED_RULE
        }
    }

    constructor() TokenGatedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__SKIP_GATE, "lens.permission.SkipGate");
        TokenGatedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validateTokenGateConfiguration(configuration.tokenGate);
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256, /* postId */
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].tokenGate,
            postParams.author
        );
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _validateTokenBalance(
        address accessControl,
        TokenGateConfiguration memory tokenGateConfiguration,
        address account
    ) internal view {
        if (!accessControl.hasAccess(account, PID__SKIP_GATE)) {
            _validateTokenBalance(tokenGateConfiguration, account);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__TOKEN_GATE) {
                configuration.tokenGate = abi.decode(params[i].value, (TokenGateConfiguration));
            }
        }
        return configuration;
    }
}
