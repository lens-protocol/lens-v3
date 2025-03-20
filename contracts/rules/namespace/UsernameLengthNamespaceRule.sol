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
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract UsernameLengthNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipMinLengthRestriction
    uint256 constant PID__SKIP_MIN_LENGTH_RESTRICTION =
        uint256(0x4e795d2b3487cc7a9b7d04dada8fb5fc0ccf8b049be6fa52eaf40ee7e08b79d6);
    /// @custom:keccak lens.permission.SkipMaxLengthRestriction
    uint256 constant PID__SKIP_MAX_LENGTH_RESTRICTION =
        uint256(0x4e5453345605763b18b5158bae028643cd90ed224a334fccfc4c406ced5e34d2);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.minLength
    bytes32 constant PARAM__MIN_LENGTH = 0x05e0174338b64de19b75800e83be51b0092b6235a3f8d74e5fe7255f433a341a;
    /// @custom:keccak lens.param.maxLength
    bytes32 constant PARAM__MAX_LENGTH = 0x1ca8667b94b405cf7da43e835d971ef185da6461852b8b81579a58637515aa69;

    /// @custom:keccak lens.storage.UsernameLengthNamespaceRule
    bytes32 constant STORAGE__USERNAME_LENGTH_NAMESPACE_RULE =
        0x08a7202baa9f254e5fee08987a4c8a3a9177d81af0c772b263c686bccb0f6ac8;

    struct LengthRestrictions {
        uint8 min;
        uint8 max;
    }

    struct Configuration {
        address accessControl;
        LengthRestrictions lengthRestrictions;
    }

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_LENGTH_NAMESPACE_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(
            PID__SKIP_MIN_LENGTH_RESTRICTION, "lens.permission.SkipMinLengthRestriction"
        );
        emit Events.Lens_PermissionId_Available(
            PID__SKIP_MAX_LENGTH_RESTRICTION, "lens.permission.SkipMaxLengthRestriction"
        );
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        require(
            configuration.lengthRestrictions.max == 0
                || configuration.lengthRestrictions.min <= configuration.lengthRestrictions.max,
            Errors.InvalidParameter()
        ); // Min length cannot be greater than max length
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt];
        uint256 usernameLength = bytes(username).length;
        if (
            configuration.lengthRestrictions.min != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, PID__SKIP_MIN_LENGTH_RESTRICTION)
        ) {
            require(usernameLength >= configuration.lengthRestrictions.min, Errors.InvalidParameter());
        }
        if (
            configuration.lengthRestrictions.max != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, PID__SKIP_MAX_LENGTH_RESTRICTION)
        ) {
            require(usernameLength <= configuration.lengthRestrictions.max, Errors.InvalidParameter());
        }
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__MIN_LENGTH) {
                configuration.lengthRestrictions.min = abi.decode(params[i].value, (uint8));
            } else if (params[i].key == PARAM__MAX_LENGTH) {
                configuration.lengthRestrictions.max = abi.decode(params[i].value, (uint8));
            }
        }
        return configuration;
    }
}
