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

contract WhitelistedSignersNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_UsernameReservedNamespaceRule_WhitelistedSignerAdded(
        address indexed usernamePrimitive, bytes32 indexed configSalt, address signerAdded
    );

    event Lens_UsernameReservedNamespaceRule_WhitelistedSignerRemoved(
        address indexed usernamePrimitive, bytes32 indexed configSalt, address signerRemoved
    );

    /// @custom:keccak lens.permission.skipUsernameWhitelistedSignersRestriction
    uint256 constant PID__SKIP_USERNAME_WHITELISTED_SIGNERS_RESTRICTION =
        uint256(0xadf51a77999063496ca738e51676f5de4b436f63acf77a519fa95defe9f097fc);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.whitelistedSignersToAdd
    bytes32 constant PARAM__WHITELISTED_SIGNERS_TO_ADD =
        0x87a27ef0b9d4341d0c6acd2514645aeb8611ff1e356c98ff3af9f7f3abc3a1b2;
    /// @custom:keccak lens.param.whitelistedSignersToRemove
    bytes32 constant PARAM__WHITELISTED_SIGNERS_TO_REMOVE =
        0xcb9722f985c55a6e8242882fcb6beea2ee88b673b93cafecb87840c861aa3c46;

    /// @custom:keccak lens.storage.WhitelistedSignersNamespaceRule
    bytes32 constant STORAGE__WHITELISTED_SIGNERS_NAMESPACE_RULE =
        0xdf046ae4dcfcc5c961d815567a11a96323144d80b4442de36935e581d965c4df;

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => address accessControl)) accessControl;
        mapping(address namespace => mapping(bytes32 configSalt => mapping(address signer => bool whitelisted)))
            isSignerWhitelisted;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__WHITELISTED_SIGNERS_NAMESPACE_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(
            PID__SKIP_USERNAME_WHITELISTED_SIGNERS_RESTRICTION,
            "lens.permission.skipUsernameWhitelistedSignersRestriction"
        );
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__WHITELISTED_SIGNERS_TO_ADD) {
                address[] memory signersToAdd = abi.decode(ruleParams[i].value, (address[]));
                for (uint256 j = 0; j < signersToAdd.length; j++) {
                    require(
                        $storage().isSignerWhitelisted[msg.sender][configSalt][signersToAdd[j]] == false,
                        Errors.RedundantStateChange()
                    );
                    $storage().isSignerWhitelisted[msg.sender][configSalt][signersToAdd[j]] = true;
                    emit Lens_UsernameReservedNamespaceRule_WhitelistedSignerAdded(
                        msg.sender, configSalt, signersToAdd[j]
                    );
                }
            } else if (ruleParams[i].key == PARAM__WHITELISTED_SIGNERS_TO_REMOVE) {
                address[] memory signersToRemove = abi.decode(ruleParams[i].value, (address[]));
                for (uint256 j = 0; j < signersToRemove.length; j++) {
                    require(
                        $storage().isSignerWhitelisted[msg.sender][configSalt][signersToRemove[j]] == true,
                        Errors.RedundantStateChange()
                    );
                    $storage().isSignerWhitelisted[msg.sender][configSalt][signersToRemove[j]] = false;
                    emit Lens_UsernameReservedNamespaceRule_WhitelistedSignerRemoved(
                        msg.sender, configSalt, signersToRemove[j]
                    );
                }
            }
        }
        if (accessControl != address(0) && $storage().accessControl[msg.sender][configSalt] != accessControl) {
            accessControl.verifyHasAccessFunction();
            $storage().accessControl[msg.sender][configSalt] = accessControl;
        }
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(
            $storage().isSignerWhitelisted[msg.sender][configSalt][originalMsgSender]
                || $storage().isSignerWhitelisted[msg.sender][configSalt][account]
                || $storage().accessControl[msg.sender][configSalt].hasAccess(
                    originalMsgSender, PID__SKIP_USERNAME_WHITELISTED_SIGNERS_RESTRICTION
                )
        );
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

    function isSignerWhitelisted(address namespace, bytes32 configSalt, address signer) external view returns (bool) {
        return $storage().isSignerWhitelisted[namespace][configSalt][signer];
    }
}
