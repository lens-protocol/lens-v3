// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IAccount, AccountManagerPermissions, Transaction} from "contracts/extensions/account/IAccount.sol";
import {SourceStamp, KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {IAccountGroupAdditionSettings} from "contracts/core/interfaces/IAccountGroupAdditionSettings.sol";
import {IRequestBasedGroupRule} from "contracts/core/interfaces/IRequestBasedGroupRule.sol";
import {SELECTOR_BYTE_LENGTH} from "contracts/core/types/Constants.sol";

library PermissionsHelper {
    function equals(AccountManagerPermissions memory permissions, AccountManagerPermissions memory otherPermissions)
        internal
        pure
        returns (bool)
    {
        return permissions.canExecuteTransactions == otherPermissions.canExecuteTransactions
            && permissions.canTransferTokens == otherPermissions.canTransferTokens
            && permissions.canTransferNative == otherPermissions.canTransferNative
            && permissions.canSetMetadataURI == otherPermissions.canSetMetadataURI;
    }

    function isAccountManager(AccountManagerPermissions memory managerPermissions) internal pure returns (bool) {
        return managerPermissions.canExecuteTransactions || managerPermissions.canSetMetadataURI;
    }
}

enum WhoCanAddMeToGroups {
    NOBODY, // Default value.
    ANYONE, // Not allowed in current implementation.
    ANYONE_I_FOLLOW_ON_SPECIFIC_GRAPHS, // Not allowed in current implementation.
    ANYONE_I_FOLLOW // Not allowed in current implementation.

}

contract Account is
    IAccount,
    IAccountGroupAdditionSettings,
    Initializable,
    Ownable,
    ExtraDataBased,
    MetadataBased,
    ERC1155Holder,
    ERC721Holder
{
    using CallLib for address;
    using PermissionsHelper for AccountManagerPermissions;

    struct Storage {
        mapping(address account => AccountManagerPermissions permissions) accountManagerPermissions;
        uint256 __gap__; // Deprecated field. It was `uint256 allowNonOwnerSpendingTimestamp`.
        WhoCanAddMeToGroups whoCanAddMeToGroups;
        mapping(address group => bool wasRequestSent) didSendRequestToGroup;
        mapping(address graph => bool usedGraph) didFollowOnGraph; // Written in current impl for future use.
        mapping(address graph => bool canAddMeToGroups) isGraphAllowedForGroupAddition; // Not written in current impl.
    }

    /// @custom:keccak lens.storage.Account
    bytes32 constant STORAGE__ACCOUNT = 0xf08a5e3d2dd76739ff9f91dc2ff8af2860b120d00f7938b9baa4607e3fee9019;

    /// @custom:keccak lens.param.graph
    bytes32 constant PARAM__GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ACCOUNT
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        string memory metadataURI,
        address[] memory accountManagers,
        AccountManagerPermissions[] memory accountManagerPermissions,
        SourceStamp memory sourceStamp,
        KeyValue[] calldata extraData
    ) external initializer {
        _initialize(metadataURI, accountManagers, accountManagerPermissions, sourceStamp, extraData);
        _transferOwnership(owner);
    }

    function _initialize(
        string memory metadataURI,
        address[] memory accountManagers,
        AccountManagerPermissions[] memory accountManagerPermissions,
        SourceStamp memory sourceStamp,
        KeyValue[] calldata extraData
    ) internal {
        for (uint256 i = 0; i < accountManagers.length; i++) {
            $storage().accountManagerPermissions[accountManagers[i]] = accountManagerPermissions[i];
            emit Lens_Account_AccountManagerAdded(accountManagers[i], accountManagerPermissions[i]);
        }
        _setExtraData(extraData);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
            _setMetadataURI(metadataURI, sourceStamp.source);
        } else {
            _setMetadataURI(metadataURI);
        }
        emit Events.Lens_Contract_Deployed({contractType: "lens.contract.Account", flavour: "lens.contract.Account"});
    }

    function _emitMetadataURISet(string memory metadataURI, address source) internal override {
        emit Lens_Account_MetadataURISet(metadataURI, source);
    }

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Lens_Account_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Lens_Account_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Lens_Account_ExtraDataRemoved(extraDataRemoved.key);
    }

    function setMetadataURI(string calldata metadataURI, SourceStamp calldata sourceStamp) external override {
        if (msg.sender != owner()) {
            require($storage().accountManagerPermissions[msg.sender].canSetMetadataURI, Errors.NotAllowed());
        }
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
            _setMetadataURI(metadataURI, sourceStamp.source);
        } else {
            _setMetadataURI(metadataURI);
        }
    }

    function canBeAddedToGroup(address group, address addedBy, KeyValue[] calldata params)
        external
        view
        override
        returns (bool)
    {
        if ($storage().whoCanAddMeToGroups == WhoCanAddMeToGroups.ANYONE) {
            return true;
        }
        if ($storage().didSendRequestToGroup[group]) {
            return true;
        }
        if (
            addedBy == address(this) || addedBy == owner()
                || $storage().accountManagerPermissions[addedBy].canExecuteTransactions
        ) {
            return true;
        }
        if ($storage().whoCanAddMeToGroups == WhoCanAddMeToGroups.NOBODY) {
            return false;
        }
        address graph = _extractGraphFromParams(params);
        if (graph == address(0)) {
            return false;
        }
        if ($storage().whoCanAddMeToGroups == WhoCanAddMeToGroups.ANYONE_I_FOLLOW) {
            // We check for isGraphAllowedForGroupAddition so allowed graphs where you didn't manually follow can be used
            return ($storage().didFollowOnGraph[graph] || $storage().isGraphAllowedForGroupAddition[graph])
                && IGraph(graph).isFollowing(address(this), addedBy);
        } else if ($storage().whoCanAddMeToGroups == WhoCanAddMeToGroups.ANYONE_I_FOLLOW_ON_SPECIFIC_GRAPHS) {
            return $storage().isGraphAllowedForGroupAddition[graph] && IGraph(graph).isFollowing(address(this), addedBy);
        }
        return false;
    }

    function _extractGraphFromParams(KeyValue[] calldata params) internal pure returns (address) {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__GRAPH) {
                return abi.decode(params[i].value, (address));
            }
        }
        return address(0);
    }

    function _beforeExecuteTransaction(address target, uint256, /* value */ bytes calldata data) internal virtual {
        if (data.length >= SELECTOR_BYTE_LENGTH) {
            bytes4 selector = bytes4(data[:SELECTOR_BYTE_LENGTH]);
            if (selector == IRequestBasedGroupRule.sendMembershipRequest.selector) {
                try this.abiDecodeForKnownSelectorHelper(selector, data[SELECTOR_BYTE_LENGTH:]) returns (address group) {
                    $storage().didSendRequestToGroup[group] = true;
                } catch {
                    return;
                }
            } else if (selector == IRequestBasedGroupRule.cancelMembershipRequest.selector) {
                try this.abiDecodeForKnownSelectorHelper(selector, data[SELECTOR_BYTE_LENGTH:]) returns (address group) {
                    $storage().didSendRequestToGroup[group] = false;
                } catch {
                    return;
                }
            } else if (selector == IGraph.follow.selector) {
                try this.abiDecodeForKnownSelectorHelper(selector, data[SELECTOR_BYTE_LENGTH:]) returns (address) {
                    $storage().didFollowOnGraph[target] = true;
                } catch {
                    return;
                }
            }
        }
    }

    function abiDecodeForKnownSelectorHelper(bytes4 selector, bytes calldata data) external pure returns (address) {
        if (selector == IRequestBasedGroupRule.sendMembershipRequest.selector) {
            (, address group,) = abi.decode(data, (bytes32, address, KeyValue[]));
            return group;
        } else if (selector == IRequestBasedGroupRule.cancelMembershipRequest.selector) {
            (, address group,) = abi.decode(data, (bytes32, address, KeyValue[]));
            return group;
        } else if (selector == IGraph.follow.selector) {
            abi.decode(data, (address, address, KeyValue[], RuleProcessingParams[], RuleProcessingParams[], KeyValue[]));
            return address(0);
        } else {
            revert Errors.NotImplemented();
        }
    }

    // Owner Only functions

    function _isAccountManager(address accountManager) internal view returns (bool) {
        return $storage().accountManagerPermissions[accountManager].isAccountManager();
    }

    function _validateAccountManagerPermissions(AccountManagerPermissions calldata permissions) internal pure {
        if (permissions.canTransferNative || permissions.canTransferTokens) {
            require(permissions.canExecuteTransactions, Errors.InvalidParameter());
        } else {
            require(permissions.isAccountManager(), Errors.InvalidParameter());
        }
    }

    function addAccountManager(address accountManager, AccountManagerPermissions calldata accountManagerPermissions)
        external
        override
        onlyOwner
    {
        require(!_isAccountManager(accountManager), Errors.RedundantStateChange());
        _validateAccountManagerPermissions(accountManagerPermissions);
        require(accountManager != owner(), Errors.InvalidParameter());
        require(accountManager != address(0), Errors.InvalidParameter());
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerAdded(accountManager, accountManagerPermissions);
    }

    function removeAccountManager(address accountManager) external override onlyOwner {
        require(_isAccountManager(accountManager), Errors.RedundantStateChange());
        delete $storage().accountManagerPermissions[accountManager];
        emit Lens_Account_AccountManagerRemoved(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require(_isAccountManager(accountManager), Errors.InvalidParameter());
        _validateAccountManagerPermissions(accountManagerPermissions);
        require(
            !$storage().accountManagerPermissions[accountManager].equals(accountManagerPermissions),
            Errors.RedundantStateChange()
        );
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external onlyOwner {
        _setExtraData(extraDataToSet);
    }

    function executeTransaction(address target, uint256 value, bytes calldata data)
        external
        payable
        override
        returns (bytes memory)
    {
        bool isMsgSenderOwner = msg.sender == owner();
        require(
            isMsgSenderOwner || $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
            Errors.NotAllowed()
        );
        return _executeTransaction(isMsgSenderOwner, target, value, data);
    }

    function executeTransactions(Transaction[] calldata transactions)
        external
        payable
        override
        returns (bytes[] memory)
    {
        bool isMsgSenderOwner = msg.sender == owner();
        require(
            isMsgSenderOwner || $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
            Errors.NotAllowed()
        );
        bytes[] memory returnData = new bytes[](transactions.length);
        for (uint256 i = 0; i < transactions.length; i++) {
            returnData[i] = _executeTransaction(
                isMsgSenderOwner, transactions[i].target, transactions[i].value, transactions[i].data
            );
        }
        return returnData;
    }

    function _executeTransaction(bool isMsgSenderOwner, address target, uint256 value, bytes calldata data)
        internal
        virtual
        returns (bytes memory)
    {
        if (!isMsgSenderOwner) {
            if (value > msg.value) {
                require($storage().accountManagerPermissions[msg.sender].canTransferNative, Errors.NotAllowed());
            }
            if (data.length >= SELECTOR_BYTE_LENGTH && _isTransferRelatedSelector(bytes4(data[:SELECTOR_BYTE_LENGTH]))) {
                require($storage().accountManagerPermissions[msg.sender].canTransferTokens, Errors.NotAllowed());
            }
        }
        _beforeExecuteTransaction(target, value, data);
        bytes memory returnData = target.handledcall(value, data);
        emit Lens_Account_TransactionExecuted(target, value, data, msg.sender);
        return returnData;
    }

    // Receiver

    receive() external payable override {}

    // Getters

    function canExecuteTransactions(address executor) external view override returns (bool) {
        return $storage().accountManagerPermissions[executor].canExecuteTransactions || executor == owner();
    }

    function isAccountManager(address accountManager) external view override returns (bool) {
        return _isAccountManager(accountManager);
    }

    function canSetMetadataURI(address accountManager) external view override returns (bool) {
        return $storage().accountManagerPermissions[accountManager].canSetMetadataURI;
    }

    function getAccountManagerPermissions(address accountManager)
        external
        view
        override
        returns (AccountManagerPermissions memory)
    {
        return $storage().accountManagerPermissions[accountManager];
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function _isTransferRelatedSelector(bytes4 selector) internal pure returns (bool) {
        // Checking only for ERC20, ERC721, ERC1155 selectors for now
        return selector == bytes4(keccak256("transfer(address,uint256)"))
            || selector == bytes4(keccak256("transferFrom(address,address,uint256)"))
            || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
            || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
            || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))
            || selector == bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))
            || selector == bytes4(keccak256("approve(address,uint256)"))
            || selector == bytes4(keccak256("setApprovalForAll(address,bool)"))
            || selector == bytes4(keccak256("increaseAllowance(address,uint256)"))
            || selector == bytes4(keccak256("decreaseAllowance(address,uint256)"));
    }

    function _transferOwnership(address newOwner) internal override {
        address oldOwner = owner();
        super._transferOwnership(newOwner);
        emit Lens_Account_OwnershipTransferred(oldOwner, newOwner);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, IERC165)
        returns (bool)
    {
        return ERC1155Receiver.supportsInterface(interfaceId);
    }
}
