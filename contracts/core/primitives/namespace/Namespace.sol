// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {NamespaceCore as Core} from "contracts/core/primitives/namespace/NamespaceCore.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedNamespace} from "contracts/core/primitives/namespace/RuleBasedNamespace.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Events} from "contracts/core/types/Events.sol";
import {LensERC721} from "contracts/core/base/LensERC721.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract Namespace is
    INamespace,
    Initializable,
    LensERC721,
    RuleBasedNamespace,
    AccessControlled,
    ExtraStorageBased,
    SourceStampBased,
    MetadataBased
{
    // TODO: Why is this event not in the INamespace interface?
    event Lens_Username_Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @custom:keccak lens.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xe40fdb273cda3c78f0d9b6d20f5378755989e26c60c89696e5eea644d84eefea);
    /// @custom:keccak lens.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0x550b12ef6572134aefc5804fd2b13ab3d8451e067ad453f67afe134cffebd977);
    /// @custom:keccak lens.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x9b4afa2e6d7162f878076bb1210736928cd607a384b985eca0dba5e94790e72a);
    /// @custom:keccak lens.permission.SetTokenURIProvider
    uint256 constant PID__SET_TOKEN_URI_PROVIDER =
        uint256(0x32b3651aa4f96bc363c3045558bf6accc2b6027323bee86f6b4a570142cbd469);

    mapping(uint256 => string) private _idToUsername; // TODO: Move to computed storage

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory namespace,
        string memory metadataURI,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider,
        IAccessControl accessControl
    ) external override initializer {
        _initialize(namespace, metadataURI);
        AccessControlled._initialize(accessControl);
        LensERC721._initialize(nftName, nftSymbol, tokenURIProvider);
    }

    function _initialize(string memory namespace, string memory metadataURI) internal {
        Core.$storage().namespace = namespace;
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("namespace", "lens.namespace", "namespace", "lens.namespace");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Namespace_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(PID__CHANGE_RULES, "lens.permission.ChangeRules");
        emit Events.Lens_PermissionId_Available(PID__SET_METADATA, "lens.permission.SetMetadata");
        emit Events.Lens_PermissionId_Available(PID__SET_EXTRA_DATA, "lens.permission.SetExtraData");
        emit Events.Lens_PermissionId_Available(PID__SET_TOKEN_URI_PROVIDER, "lens.permission.SetTokenURIProvider");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_TOKEN_URI_PROVIDER);
    }

    function _beforeChangePrimitiveRules(RuleChange[] calldata /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }
    // Permissionless functions

    function createAndAssignUsername(
        address account,
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningProcessingParams,
        RuleProcessingParams[] calldata creationProcessingParams,
        RuleProcessingParams[] memory assigningProcessingParams,
        KeyValue[] memory extraData
    ) external {
        // require(msg.sender == account, Errors.InvalidMsgSender());
        // uint256 id = _computeId(username);
        // _safeMint(account, id);
        // _idToUsername[id] = username;
        // Core._createUsername(username);
        // address source = _processSourceStamp(id, customParams);
        // _decodeAndSetUsernameExtraData(id, extraData);
        // emit Lens_Username_Created(username, account, customParams, creationProcessingParams, source, extraData);
        // _unassignIfAssigned(account, customParams, unassigningProcessingParams, source);
        // Core._assignUsername(account, username);
        // emit Lens_Username_Assigned(username, account, customParams, assigningProcessingParams, source);
        // _processCreation(msg.sender, account, username, customParams, creationProcessingParams);
        // _processAssigning(msg.sender, account, username, customParams, assigningProcessingParams);
    }

    function createUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        KeyValue[] calldata extraData
    ) external override {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 id = _computeId(username);
        _safeMint(account, id);
        _idToUsername[id] = username;
        Core._createUsername(username);
        _processCreation(msg.sender, account, username, customParams, ruleProcessingParams);
        address source = _processSourceStamp(id, customParams);
        _decodeAndSetUsernameExtraData(id, extraData);
        emit Lens_Username_Created(username, account, customParams, ruleProcessingParams, source, extraData);
    }

    function removeUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningRuleProcessingParams,
        RuleProcessingParams[] calldata removalRuleProcessingParams
    ) external override {
        uint256 id = _computeId(username);
        address owner = _ownerOf(id);
        require(msg.sender == owner, Errors.InvalidMsgSender()); // msg.sender must be the owner of the username
        _processRemoval(msg.sender, username, customParams, removalRuleProcessingParams);
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
    ) external override {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 id = _computeId(username);
        require(account == _ownerOf(id), Errors.InvalidMsgSender()); // account should own the tokenized username
        address source = _processSourceStamp(id, customParams);
        _unassignIfAssigned(account, customParams, unassignAccountRuleProcessingParams, source);
        _unassignIfAssigned(username, customParams, unassignUsernameRuleProcessingParams, source);
        Core._assignUsername(account, username);
        _processAssigning(msg.sender, account, username, customParams, assignRuleProcessingParams);
        emit Lens_Username_Assigned(username, account, customParams, assignRuleProcessingParams, source);
    }

    function unassignUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        address account = Core.$storage().usernameToAccount[username];
        uint256 id = _computeId(username);
        require(msg.sender == account || msg.sender == _ownerOf(id), Errors.InvalidMsgSender());
        Core._unassignUsername(username);
        _processUnassigning(msg.sender, account, username, customParams, ruleProcessingParams);
        address source = _processSourceStamp(id, customParams);
        emit Lens_Username_Unassigned(username, account, customParams, ruleProcessingParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setPrimitiveExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Namespace_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Namespace_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Namespace_ExtraDataAdded(
                    extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                );
            }
        }
    }

    function setUsernameExtraData(string calldata username, KeyValue[] calldata extraDataToSet) external {
        uint256 id = _computeId(username);
        address owner = _ownerOf(id);
        require(msg.sender == owner, Errors.InvalidMsgSender());
        _decodeAndSetUsernameExtraData(id, extraDataToSet);
    }

    // Internal

    function _decodeAndSetUsernameExtraData(uint256 tokenId, KeyValue[] memory extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setEntityExtraData(tokenId, extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Username_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Username_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Username_ExtraDataAdded(
                    extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                );
            }
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        emit Lens_Username_Transfer(from, to, tokenId);
    }

    function _computeId(string memory username) internal pure virtual returns (uint256) {
        return uint256(keccak256(bytes(username)));
    }

    function _unassignIfAssigned(
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal virtual {
        address assignedAccount = Core.$storage().usernameToAccount[username];
        if (assignedAccount != address(0)) {
            Core._unassignUsername(username);
            _processUnassigning(msg.sender, assignedAccount, username, customParams, ruleProcessingParams);
            emit Lens_Username_Unassigned(username, assignedAccount, customParams, ruleProcessingParams, source);
        }
    }

    function _unassignIfAssigned(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal virtual {
        string memory assignedUsername = Core.$storage().accountToUsername[account];
        if (bytes(assignedUsername).length != 0) {
            Core._unassignUsername(assignedUsername);
            _processUnassigning(msg.sender, account, assignedUsername, customParams, ruleProcessingParams);
            emit Lens_Username_Unassigned(assignedUsername, account, customParams, ruleProcessingParams, source);
        }
    }

    // Getters

    function usernameOf(address user) external view returns (string memory) {
        string memory username = Core.$storage().accountToUsername[user];
        require(bytes(username).length != 0, Errors.DoesNotExist());
        return username;
    }

    function accountOf(string memory username) external view returns (address) {
        uint256 tokenId = _computeId(username);
        require(_exists(tokenId), Errors.DoesNotExist());
        return Core.$storage().usernameToAccount[username];
    }

    function getNamespace() external view returns (string memory) {
        return Core.$storage().namespace;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getPrimitiveExtraData(key);
    }

    function getUsernameExtraData(string calldata username, bytes32 key) external view override returns (bytes memory) {
        uint256 tokenId = _computeId(username);
        address owner = ownerOf(tokenId);
        return _getEntityExtraData(owner, tokenId, key);
    }
}
