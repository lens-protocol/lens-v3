// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "./../../core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {MetadataBased} from "./../../core/base/MetadataBased.sol";

contract UsernameReservedNamespaceRule is INamespaceRule, MetadataBased {
    event Lens_Rule_MetadataURISet(string metadataURI);

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

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;
    // keccak256("lens.rules.namespace.UsernameReservedNamespaceRule.param.key.usernamesToReserve");
    bytes32 immutable USERNAMES_TO_RESERVE_PARAM_KEY = 0xac73ea9176302dedf93d018cb2851aabed8378e612d5c8f094b84162baf60a54;
    // keccak256("lens.rules.namespace.UsernameReservedNamespaceRule.param.key.usernamesToRelease");
    bytes32 immutable USERNAMES_TO_RELEASE_PARAM_KEY = 0xf39a11cac75c11509a76f28c17d7d93727c605b6426fb4783e74703c68005563;

    uint256 constant CREATE_RESERVED_USERNAME_PID = uint256(keccak256("CREATE_RESERVED_USERNAME"));

    mapping(address => mapping(bytes32 => address)) internal _accessControl;
    mapping(address => mapping(bytes32 => mapping(string => bool))) internal _isUsernameReserved;

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
        emit Events.Lens_PermissionId_Available(CREATE_RESERVED_USERNAME_PID, "CREATE_RESERVED_USERNAME");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == ACCESS_CONTROL_PARAM_KEY) {
                accessControl = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == USERNAMES_TO_RESERVE_PARAM_KEY) {
                string[] memory usernamesToReserve = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToReserve.length; j++) {
                    require(!_isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]]);
                    _isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]] = true;
                    emit Lens_UsernameReservedNamespaceRule_UsernameReserved(
                        msg.sender, configSalt, usernamesToReserve[j], usernamesToReserve[j]
                    );
                }
            } else if (ruleParams[i].key == USERNAMES_TO_RELEASE_PARAM_KEY) {
                string[] memory usernamesToRelease = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToRelease.length; j++) {
                    require(_isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]]);
                    _isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]] = false;
                    emit Lens_UsernameReservedNamespaceRule_UsernameReleased(
                        msg.sender, configSalt, usernamesToRelease[j], usernamesToRelease[j]
                    );
                }
            }
        }
        accessControl.verifyHasAccessFunction();
        _accessControl[msg.sender][configSalt] = accessControl;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        if (_isUsernameReserved[msg.sender][configSalt][username]) {
            _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, CREATE_RESERVED_USERNAME_PID);
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
}
