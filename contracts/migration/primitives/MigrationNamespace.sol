// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {NamespaceCore as Core} from "contracts/core/primitives/namespace/NamespaceCore.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {KeyValueStorageLib} from "contracts/core/libraries/KeyValueStorageLib.sol";
import {RuleProcessingParams} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {WHITELISTED_MULTICALL_ADDRESS} from "contracts/migration/WhitelistedMulticall.sol";
import {LensERC721} from "contracts/core/base/LensERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract MigrationNamespace is Namespace {
    using KeyValueStorageLib for mapping(bytes32 => bytes);

    /// @custom:keccak lens.storage.LensFactory
    bytes32 constant STORAGE__LENS_FACTORY = 0x693c7aa9b36894cf47d816ba6924c41c2b869eee973e360eacb8f3e4239e8cb3;

    struct AddressStorage {
        address value;
    }

    modifier onlyWhitelistedMulticall() {
        require(msg.sender == WHITELISTED_MULTICALL_ADDRESS, Errors.InvalidMsgSender());
        _;
    }

    modifier onlyLensFactory() {
        require(msg.sender == $lensFactory().value, Errors.InvalidMsgSender());
        _;
    }

    modifier onlyLensFactoryOrMulticall() {
        require(
            msg.sender == $lensFactory().value || msg.sender == WHITELISTED_MULTICALL_ADDRESS, Errors.InvalidMsgSender()
        );
        _;
    }

    function $lensFactory() internal pure returns (AddressStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__LENS_FACTORY
        }
    }

    function setLensFactory(address lensFactory) external onlyWhitelistedMulticall {
        $lensFactory().value = lensFactory;
    }

    function $migrationExtraStorage() private pure returns (ExtraStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__EXTRA_STORAGE
        }
    }

    function _decodeAndSetUsernameExtraData(uint256 tokenId, KeyValue[] memory extraDataToSet) internal override {
        address usernameOwner = ownerOf(tokenId);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            // Storing extra data in the native extra storage for data integrity
            _setEntityExtraStorage(tokenId, extraDataToSet[i]);
            // Forcing ExtraStorageBased::_setEntityExtraStorage_Account with injected addressScope
            _migration_force__setEntityExtraStorage_Account(usernameOwner, tokenId, extraDataToSet[i]);
            emit Lens_Username_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    function _migration_force__setEntityExtraStorage_Account(
        address addressScope,
        uint256 entityId,
        KeyValue memory extraDataToSet
    ) private {
        // In this release we always set the entityID to zero
        $migrationExtraStorage().slot[addressScope][0][entityId].set(extraDataToSet);
        emit Lens_ExtraStorageSet(addressScope, entityId, extraDataToSet.key, extraDataToSet.value);
    }

    function migration_force__setNameAndSymbol(string calldata name, string calldata symbol)
        external
        onlyWhitelistedMulticall
    {
        $erc721Storage().name = name;
        $erc721Storage().symbol = symbol;
    }

    function removeUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningRuleProcessingParams,
        RuleProcessingParams[] calldata removalRuleProcessingParams
    ) external virtual override onlyWhitelistedMulticall {
        uint256 id = _computeId(username);
        address owner = ownerOf(id);
        // !!! MIGRATION ONLY
        // require(msg.sender == owner, Errors.InvalidMsgSender()); // msg.sender must be the owner of the username
        // _processRemoval(msg.sender, username, customParams, removalRuleProcessingParams);
        address source = _processSourceStamp(id, customParams);
        _unassignIfAssigned(username, customParams, unassigningRuleProcessingParams, source);
        _burn(id);
        Core._removeUsername(username);
        emit Lens_Username_Removed(username, owner, customParams, removalRuleProcessingParams, source);
    }

    function assignUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassignAccountRuleProcessingParams,
        RuleProcessingParams[] calldata unassignUsernameRuleProcessingParams,
        RuleProcessingParams[] calldata assignRuleProcessingParams
    ) external virtual override onlyWhitelistedMulticall {
        uint256 id = _computeId(username);
        // account should own the tokenized username and be the msg.sender
        // !!! MIGRATION ONLY
        // require(msg.sender == ownerOf(id) && msg.sender == account, Errors.InvalidMsgSender());
        // Check if username is not already assigned to this account
        require(account != Core.$storage().usernameToAccount[username], Errors.RedundantStateChange());
        address source = _processSourceStamp(id, customParams);
        _unassignIfAssigned(account, customParams, unassignAccountRuleProcessingParams, source);
        _unassignIfAssigned(username, customParams, unassignUsernameRuleProcessingParams, source);
        Core._assignUsername(account, username);
        // !!! MIGRATION ONLY
        // _processAssigning(msg.sender, account, username, customParams, assignRuleProcessingParams);
        emit Lens_Username_Assigned(username, account, customParams, assignRuleProcessingParams, source);
    }

    function unassignUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external virtual override onlyWhitelistedMulticall {
        address account = Core.$storage().usernameToAccount[username];
        uint256 id = _computeId(username);
        // !!! MIGRATION ONLY
        // require(msg.sender == ownerOf(id) || msg.sender == account, Errors.InvalidMsgSender());
        Core._unassignUsername(username);
        // !!! MIGRATION ONLY
        // _processUnassigning(msg.sender, account, username, customParams, ruleProcessingParams);
        address source = _processSourceStamp(id, customParams);
        emit Lens_Username_Unassigned(username, account, customParams, ruleProcessingParams, source);
    }

    function createAndAssignUsername(
        address account,
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningProcessingParams,
        RuleProcessingParams[] calldata creationProcessingParams,
        RuleProcessingParams[] calldata assigningProcessingParams,
        KeyValue[] memory extraData
    ) external virtual override onlyLensFactoryOrMulticall {
        // !!! MIGRATION ONLY
        // require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 id = _computeId(username);
        _safeMint(account, id);
        $storage().idToUsername[id] = username;
        Core._createUsername(username);
        address source = _processSourceStamp(id, customParams);
        _decodeAndSetUsernameExtraData(id, extraData);
        emit Lens_Username_Created(username, account, customParams, creationProcessingParams, source, extraData);
        _unassignIfAssigned(account, customParams, unassigningProcessingParams, source);
        Core._assignUsername(account, username);
        emit Lens_Username_Assigned(username, account, customParams, assigningProcessingParams, source);
        // !!! MIGRATION ONLY
        // _processCreation(msg.sender, account, username, customParams, creationProcessingParams);
        // _processAssigning(msg.sender, account, username, customParams, assigningProcessingParams);
    }

    function createUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        KeyValue[] calldata extraData
    ) external virtual override onlyLensFactoryOrMulticall {
        uint256 id = _computeId(username);
        _safeMint(account, id);
        $storage().idToUsername[id] = username;
        Core._createUsername(username);
        // !!! MIGRATION ONLY
        // _processCreation(msg.sender, account, username, customParams, ruleProcessingParams);
        address source = _processSourceStamp(id, customParams);
        _decodeAndSetUsernameExtraData(id, extraData);
        emit Lens_Username_Created(username, account, customParams, ruleProcessingParams, source, extraData);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(LensERC721, IERC721) {
        // !!! MIGRATION ONLY
        // require(_isApprovedOrOwner(msg.sender, tokenId), Errors.InvalidMsgSender());
        require(
            _isApprovedOrOwner(msg.sender, tokenId) || msg.sender == $lensFactory().value
                || msg.sender == WHITELISTED_MULTICALL_ADDRESS,
            Errors.InvalidMsgSender()
        );

        _transfer(from, to, tokenId);
    }

    function _unassignIfAssigned(
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal override {
        address assignedAccount = Core.$storage().usernameToAccount[username];
        if (assignedAccount != address(0)) {
            Core._unassignUsername(username);
            // !!! MIGRATION ONLY
            // _processUnassigning(msg.sender, assignedAccount, username, customParams, ruleProcessingParams);
            emit Lens_Username_Unassigned(username, assignedAccount, customParams, ruleProcessingParams, source);
        }
    }

    function _unassignIfAssigned(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal override {
        string memory assignedUsername = Core.$storage().accountToUsername[account];
        if (bytes(assignedUsername).length != 0) {
            Core._unassignUsername(assignedUsername);
            // !!! MIGRATION ONLY
            // _processUnassigning(msg.sender, account, assignedUsername, customParams, ruleProcessingParams);
            emit Lens_Username_Unassigned(assignedUsername, account, customParams, ruleProcessingParams, source);
        }
    }
}
