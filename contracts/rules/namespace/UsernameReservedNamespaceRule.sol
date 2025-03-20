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

contract UsernameReservedNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_UsernameReservedNamespaceRule_UsernameReserved(
        address indexed usernamePrimitive, bytes32 indexed configSalt, string indexed indexedUsername, string username
    );
    event Lens_UsernameReservedNamespaceRule_UsernameReleased(
        address indexed usernamePrimitive, bytes32 indexed configSalt, string indexed indexedUsername, string username
    );
    event Lens_UsernameReservedNamespaceRule_ReservedUsernameCreated(
        address indexed usernamePrimitive,
        bytes32 indexed configSalt,
        string indexed indexedUsername,
        string username,
        address account,
        address createdBy
    );

    /// @custom:keccak lens.permission.CreateReservedUsername
    uint256 constant PID__CREATE_RESERVED_USERNAME =
        uint256(0xf94dde6e939068e103ec2e4fe1d167e5a2c1beb18cd5214e57207fd2e92507de);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.usernamesToReserve
    bytes32 constant PARAM__USERNAMES_TO_RESERVE = 0xf26be09bbd76bd72f4bb3b9191df07efee6b4e7a2e71571f78b583bac6f8c8bc;
    /// @custom:keccak lens.param.usernamesToRelease
    bytes32 constant PARAM__USERNAMES_TO_RELEASE = 0x81011f9338fa0fd1bac6372a385bfd0c2763bf18ec154f09ad5b6688b943b6dc;

    /// @custom:keccak lens.storage.UsernameReservedNamespaceRule
    bytes32 constant STORAGE__USERNAME_RESERVED_NAMESPACE_RULE =
        0xa08559feca4ccbf88f5987d492116b3568a32a24d348dca81dc1af9040c43847;

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => address accessControl)) accessControl;
        mapping(address group => mapping(bytes32 configSalt => mapping(string username => bool reserved)))
            isUsernameReserved;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_RESERVED_NAMESPACE_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__CREATE_RESERVED_USERNAME, "lens.permission.CreateReservedUsername");
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__USERNAMES_TO_RESERVE) {
                string[] memory usernamesToReserve = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToReserve.length; j++) {
                    require(
                        !$storage().isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]],
                        Errors.RedundantStateChange()
                    );
                    $storage().isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]] = true;
                    emit Lens_UsernameReservedNamespaceRule_UsernameReserved(
                        msg.sender, configSalt, usernamesToReserve[j], usernamesToReserve[j]
                    );
                }
            } else if (ruleParams[i].key == PARAM__USERNAMES_TO_RELEASE) {
                string[] memory usernamesToRelease = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToRelease.length; j++) {
                    require(
                        $storage().isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]],
                        Errors.RedundantStateChange()
                    );
                    $storage().isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]] = false;
                    emit Lens_UsernameReservedNamespaceRule_UsernameReleased(
                        msg.sender, configSalt, usernamesToRelease[j], usernamesToRelease[j]
                    );
                }
            }
        }
        accessControl.verifyHasAccessFunction();
        $storage().accessControl[msg.sender][configSalt] = accessControl;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        if ($storage().isUsernameReserved[msg.sender][configSalt][username]) {
            $storage().accessControl[msg.sender][configSalt].requireAccess(
                originalMsgSender, PID__CREATE_RESERVED_USERNAME
            );
            emit Lens_UsernameReservedNamespaceRule_ReservedUsernameCreated(
                msg.sender, configSalt, username, username, account, originalMsgSender
            );
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
}
