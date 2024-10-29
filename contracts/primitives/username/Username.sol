// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UsernameCore as Core} from "./UsernameCore.sol";
import {IUsernameRule} from "./IUsernameRule.sol";
import {IUsername} from "./IUsername.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {DataElement, RuleExecutionData, RuleConfiguration, DataElementValue} from "./../../types/Types.sol";
import {RuleBasedUsername} from "./RuleBasedUsername.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {RuleConfiguration} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";
import {LensERC721} from "../base/LensERC721.sol";
import {ITokenURIProvider} from "../base/ITokenURIProvider.sol";

contract Username is IUsername, LensERC721, RuleBasedUsername, AccessControlled {
    // TODO: Do we want more granular resources here? Like add/update/remove PIDs? Or are we OK with the multi-purpose?
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant SET_TOKEN_URI_PROVIDER_PID = uint256(keccak256("SET_TOKEN_URI_PROVIDER"));

    // TODO: This will be a mandatory rule now
    // // Storage fields and structs
    // struct LengthRestriction {
    //     uint8 min;
    //     uint8 max;
    // }

    // TODO: We need initializer for all primitives to make them upgradeable
    constructor(
        string memory namespace,
        address metadataURISource,
        string memory metadataURI,
        IAccessControl accessControl,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) LensERC721(nftName, nftSymbol, tokenURIProvider) AccessControlled(accessControl) {
        Core.$storage().namespace = namespace;
        Core.$storage().metadataURI[metadataURISource] = metadataURI;
        emit Lens_Username_MetadataURISet(metadataURISource, metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("username", "lens.username", "username", "lens.username");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Lens_PermissonId_Available(SET_RULES_PID, "SET_RULES");
        emit Lens_PermissonId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Lens_PermissonId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
        emit Lens_PermissonId_Available(SET_TOKEN_URI_PROVIDER_PID, "SET_TOKEN_URI_PROVIDER");
    }

    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal view override {
        _requireAccess(msg.sender, SET_TOKEN_URI_PROVIDER_PID);
    }

    // Access Controlled functions

    function setMetadataURI(address source, string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI[source] = metadataURI;
        emit Lens_Username_MetadataURISet(source, metadataURI);
    }

    function addUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < ruleConfigurations.length; i++) {
            _addUsernameRule(ruleConfigurations[i]);
            emit Lens_Username_RuleAdded(
                ruleConfigurations[i].ruleAddress, ruleConfigurations[i].configData, ruleConfigurations[i].isRequired
            );
        }
    }

    function updateUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < ruleConfigurations.length; i++) {
            _updateUsernameRule(ruleConfigurations[i]);
            emit Lens_Username_RuleUpdated(
                ruleConfigurations[i].ruleAddress, ruleConfigurations[i].configData, ruleConfigurations[i].isRequired
            );
        }
    }

    function removeUsernameRules(address[] calldata rules) external {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeUsernameRule(rules[i]);
            emit Lens_Username_RuleRemoved(rules[i]);
        }
    }

    // Permissionless functions

    function createUsername(address account, string calldata username, RuleExecutionData calldata data)
        external
        override
    {
        require(msg.sender == account); // msg.sender must be the account
        uint256 id = _computeId(username);
        _safeMint(account, id);
        Core._createUsername(username);
        _processCreation(account, username, data);
        // _validateUsernameLength(username);
        emit Lens_Username_Created(username, account, data);
    }

    function removeUsername(string calldata username, RuleExecutionData calldata data) external override {
        uint256 id = _computeId(username);
        address account = _ownerOf(id);
        require(msg.sender == account); // msg.sender must be the owner of the username
        _burn(id);
        Core._removeUsername(username);
        _processRemoval(account, username, data);
        emit Lens_Username_Removed(username, account, data);
    }

    function assignUsername(address account, string calldata username, RuleExecutionData calldata data)
        external
        override
    {
        require(msg.sender == account); // msg.sender must be the account
        Core._assignUsername(account, username);
        _processAssigning(account, username, data);
        emit Lens_Username_Assigned(username, account, data);
    }

    function unassignUsername(string calldata username, RuleExecutionData calldata data) external override {
        address account = Core.$storage().usernameToAccount[username];
        require(msg.sender == account); // msg.sender must be the account
        Core._unassignUsername(username);
        _processUnassigning(account, username, data);
        emit Lens_Username_Unassigned(username, account, data);
    }

    // TODO: Decide if it worth to have a "before/after" hook for the rules, or if we are covered just with the "before"
    // Think about CEI pattern and if we are OK with the "before", because it looks more like CIE than CEI.
    // function assignUsername(address account, string memory username, bytes calldata data) external {
    //     require(msg.sender == account); // msg.sender must be the account
    //     IUsernameRule(Core.$storage().usernameRules).beforeAssigning(msg.sender, account, username, data);
    //     Core._assignUsername(account, username);
    //     IUsernameRule(Core.$storage().usernameRules).afterAssigning(msg.sender, account, username, data);
    //     emit Lens_Username_Assigned(username, account, data);
    // }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool wasExtraDataAlreadySet = Core._setExtraData(extraDataToSet[i]);
            if (wasExtraDataAlreadySet) {
                emit Lens_Username_ExtraDataUpdated(
                    extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                );
            } else {
                emit Lens_Username_ExtraDataAdded(
                    extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                );
            }
        }
    }

    function removeExtraData(bytes32[] calldata extraDataKeysToRemove) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataKeysToRemove.length; i++) {
            Core._removeExtraData(extraDataKeysToRemove[i]);
            emit Lens_Username_ExtraDataRemoved(extraDataKeysToRemove[i]);
        }
    }

    // Internal

    function _computeId(string memory username) internal pure returns (uint256) {
        return uint256(keccak256(bytes(username)));
    }

    // function _validateUsernameLength(string memory username) internal pure {
    //     // TODO: Add the PIDs for skipping length restrictions.
    //     LengthRestriction memory lengthRestriction = $lengthRestriction();
    //     uint256 usernameLength = bytes(username).length;
    //     if (lengthRestriction.min != 0) {
    //         require(usernameLength >= lengthRestriction.min, "Username: too short");
    //     }
    //     if (lengthRestriction.max != 0) {
    //         // TODO: If no restriction, should be max(uint8), not unlimited! - API will be like that
    //         require(usernameLength <= lengthRestriction.max, "Username: too long");
    //     }
    // }

    // Storage utility & helper functions

    // // keccak256('lens.username.storage.length.restriction')
    // bytes32 constant LENGTH_RESTRICTION_STORAGE_SLOT =
    //     0x2d828a00137871809f1a4bee7ddd78f42d45a25fe20299ceaf25638343e83134;

    // function $lengthRestriction() internal pure returns (LengthRestriction storage _lengthRestriction) {
    //     assembly {
    //         _lengthRestriction.slot := LENGTH_RESTRICTION_STORAGE_SLOT
    //     }
    // }

    // Getters

    // TODO: getUsernameOf?
    function usernameOf(address user) external view returns (string memory) {
        return Core.$storage().accountToUsername[user];
    }

    // TODO: getAccountOf?
    function accountOf(string memory name) external view returns (address) {
        return Core.$storage().usernameToAccount[name];
    }

    function getNamespace() external view returns (string memory) {
        return Core.$storage().namespace;
    }

    function getExtraData(bytes32 key) external view override returns (DataElementValue memory) {
        return Core.$storage().extraData[key];
    }

    function getUsernameRules(bool isRequired) external view override returns (address[] memory) {
        return _getUsernameRules(isRequired);
    }

    function getMetadataURI(address source) external view override returns (string memory) {
        return Core.$storage().metadataURI[source];
    }
}
