// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {Events} from "contracts/core/types/Events.sol";
import {
    IAccount, AccountManagerPermissions, Transaction, AllowanceChange
} from "contracts/extensions/account/IAccount.sol";
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
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

library PermissionsHelper {
    function equals(AccountManagerPermissions memory permissions, AccountManagerStorage memory storagePermissions)
        internal
        pure
        returns (bool)
    {
        return permissions.canExecuteTransactions == storagePermissions.canExecuteTransactions
            && permissions.canTransferTokens == storagePermissions.canTransferTokens
            && permissions.canSetMetadataURI == storagePermissions.canSetMetadataURI;
    }

    function equals(AccountManagerStorage memory storagePermissions, AccountManagerPermissions memory permissions)
        internal
        pure
        returns (bool)
    {
        return equals(permissions, storagePermissions);
    }

    function isAccountManager(AccountManagerPermissions memory managerPermissions) internal pure returns (bool) {
        return managerPermissions.canExecuteTransactions || managerPermissions.canSetMetadataURI;
    }

    function isAccountManager(AccountManagerStorage memory managerPermissions) internal pure returns (bool) {
        return managerPermissions.canExecuteTransactions || managerPermissions.canSetMetadataURI;
    }

    function toAccountManagerPermissions(AccountManagerStorage memory storagePermissions)
        internal
        pure
        returns (AccountManagerPermissions memory)
    {
        return AccountManagerPermissions({
            canExecuteTransactions: storagePermissions.canExecuteTransactions,
            canTransferTokens: storagePermissions.canTransferTokens,
            canTransferNative: storagePermissions.canTransferTokens, // Intentionally derived from `canTransferTokens`
            canSetMetadataURI: storagePermissions.canSetMetadataURI
        });
    }

    function updatePermissionsTo(
        AccountManagerStorage storage _storagePermissions,
        AccountManagerPermissions memory permission
    ) internal {
        _storagePermissions.canExecuteTransactions = permission.canExecuteTransactions;
        _storagePermissions.canTransferTokens = permission.canTransferTokens;
        _storagePermissions.canSetMetadataURI = permission.canSetMetadataURI;
    }

    function clearPermissions(AccountManagerStorage storage _storagePermissions) internal {
        delete _storagePermissions.canExecuteTransactions;
        delete _storagePermissions.canTransferTokens;
        delete _storagePermissions.canSetMetadataURI;
    }
}

struct AccountManagerStorage {
    bool canExecuteTransactions;
    bool canTransferTokens;
    bool __deprecated__; // It was `bool canTransferNative`.
    bool canSetMetadataURI;
    uint192 __gap__;
    uint32 allowanceKey;
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
    using PermissionsHelper for AccountManagerStorage;

    struct Storage {
        mapping(address manager => AccountManagerStorage permissions) managerStorage;
        uint256 __deprecated__; // It was `uint256 allowNonOwnerSpendingTimestamp`.
        WhoCanAddMeToGroups whoCanAddMeToGroups;
        mapping(address group => bool wasRequestSent) didSendRequestToGroup;
        mapping(address graph => bool usedGraph) didFollowOnGraph; // Written in current impl for future use.
        mapping(address graph => bool canAddMeToGroups) isGraphAllowedForGroupAddition; // Not written in current impl.
        mapping(address manager => mapping(uint256 key => mapping(address currency => uint256 allowance))) allowance;
    }

    /// @custom:keccak lens.storage.Account
    bytes32 constant STORAGE__ACCOUNT = 0xf08a5e3d2dd76739ff9f91dc2ff8af2860b120d00f7938b9baa4607e3fee9019;

    /// @custom:keccak lens.param.graph
    bytes32 constant PARAM__GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;

    address immutable GHO;
    address immutable WGHO;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ACCOUNT
        }
    }

    constructor(address nativeGHO, address wrappedGHO) {
        GHO = nativeGHO;
        WGHO = wrappedGHO;
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
        AccountManagerPermissions[] memory permissions,
        SourceStamp memory sourceStamp,
        KeyValue[] calldata extraData
    ) internal {
        for (uint256 i = 0; i < accountManagers.length; i++) {
            _addAccountManager(accountManagers[i], permissions[i]);
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
            require($storage().managerStorage[msg.sender].canSetMetadataURI, Errors.NotAllowed());
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
        if (addedBy == address(this) || addedBy == owner() || $storage().managerStorage[addedBy].canExecuteTransactions)
        {
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

    function abiDecodeForKnownSelectorHelper(bytes4 selector, bytes calldata encodedParams)
        external
        pure
        returns (address, uint256, address)
    {
        if (
            selector == bytes4(keccak256("transferFrom(address,address,uint256)"))
                || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
        ) {
            (address from, address to, uint256 amount) = abi.decode(encodedParams, (address, address, uint256));
            return (from, amount, to);
        } else if (
            selector == bytes4(keccak256("transfer(address,uint256)"))
                || selector == bytes4(keccak256("approve(address,uint256)"))
                || selector == bytes4(keccak256("increaseAllowance(address,uint256)"))
        ) {
            (address to, uint256 amount) = abi.decode(encodedParams, (address, uint256));
            return (to, amount, address(0));
        } else if (selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))) {
            (address from, address to, uint256 amount,) = abi.decode(encodedParams, (address, address, uint256, bytes));
            return (from, amount, to);
        } else if (selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))) {
            (address from, address to, uint256 amount,,) =
                abi.decode(encodedParams, (address, address, uint256, uint256, bytes));
            return (from, amount, to);
        } else if (selector == bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))) {
            (address from, address to,,,) = abi.decode(encodedParams, (address, address, uint256[], uint256[], bytes));
            return (from, 0, to);
        } else if (selector == bytes4(keccak256("setApprovalForAll(address,bool)"))) {
            (address operator,) = abi.decode(encodedParams, (address, bool));
            return (operator, 0, address(0));
        } else if (
            selector == IRequestBasedGroupRule.sendMembershipRequest.selector
                || selector == IRequestBasedGroupRule.cancelMembershipRequest.selector
        ) {
            (, address group,) = abi.decode(encodedParams, (bytes32, address, KeyValue[]));
            return (group, 0, address(0));
        } else if (selector == IGraph.follow.selector) {
            abi.decode(
                encodedParams, (address, address, KeyValue[], RuleProcessingParams[], RuleProcessingParams[], KeyValue[])
            );
            return (address(0), 0, address(0));
        } else {
            revert Errors.NotImplemented();
        }
    }

    // Owner Only functions

    function _isAccountManager(address accountManager) internal view returns (bool) {
        return $storage().managerStorage[accountManager].isAccountManager();
    }

    function _validateAccountManagerPermissions(AccountManagerPermissions memory permissions) internal pure {
        // Both permissions are merged into a single one, to not break interface, we require them to match.
        require(permissions.canTransferNative == permissions.canTransferTokens, Errors.InvalidParameter());
        if (permissions.canTransferTokens) {
            require(permissions.canExecuteTransactions, Errors.InvalidParameter());
        } else {
            require(permissions.isAccountManager(), Errors.InvalidParameter());
        }
    }

    function addAccountManager(address accountManager, AccountManagerPermissions calldata permissions)
        external
        override
        onlyOwner
    {
        _addAccountManager(accountManager, permissions);
    }

    function removeAccountManager(address accountManager) external override {
        // Manager can remove itself.
        require(msg.sender == owner() || msg.sender == accountManager, Errors.InvalidMsgSender());
        require(_isAccountManager(accountManager), Errors.RedundantStateChange());
        _removeAccountManager(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require(_isAccountManager(accountManager), Errors.InvalidParameter());
        _validateAccountManagerPermissions(accountManagerPermissions);
        require(
            !$storage().managerStorage[accountManager].equals(accountManagerPermissions), Errors.RedundantStateChange()
        );
        if ($storage().managerStorage[accountManager].canTransferTokens && !accountManagerPermissions.canTransferTokens)
        {
            _clearAllAllowances(accountManager);
        }
        $storage().managerStorage[accountManager].updatePermissionsTo(accountManagerPermissions);
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function changeAllowance(AllowanceChange[] calldata allowanceChanges) external override onlyOwner {
        for (uint256 i = 0; i < allowanceChanges.length; i++) {
            for (uint256 j = 0; j < allowanceChanges[i].allowanceDecreases.length; j++) {
                require(_isAccountManager(allowanceChanges[i].spender), Errors.InvalidParameter());
                require(
                    $storage().managerStorage[allowanceChanges[i].spender].canTransferTokens == false,
                    Errors.InvalidParameter() // Manager has infinite allowance by canTransferTokens permission
                );
                _decreaseAllowance(
                    allowanceChanges[i].spender,
                    allowanceChanges[i].allowanceDecreases[j].currency,
                    allowanceChanges[i].allowanceDecreases[j].byAmount
                );
            }
            for (uint256 j = 0; j < allowanceChanges[i].allowanceIncreases.length; j++) {
                require(_isAccountManager(allowanceChanges[i].spender), Errors.InvalidParameter());
                require(
                    $storage().managerStorage[allowanceChanges[i].spender].canTransferTokens == false,
                    Errors.RedundantStateChange() // Manager has infinite allowance by canTransferTokens permission
                );
                _increaseAllowance(
                    allowanceChanges[i].spender,
                    allowanceChanges[i].allowanceIncreases[j].currency,
                    allowanceChanges[i].allowanceIncreases[j].byAmount
                );
            }
        }
    }

    function clearAllAllowances(address[] calldata managers) external override onlyOwner {
        for (uint256 i = 0; i < managers.length; i++) {
            _clearAllAllowances(managers[i]);
        }
    }

    function _clearAllAllowances(address manager) internal {
        $storage().managerStorage[manager].allowanceKey++;
        emit Lens_Account_AllAllowancesCleared(manager);
    }

    function _increaseAllowance(address spender, address currency, uint256 byAmount) internal returns (uint256) {
        uint256 allowanceKey = $storage().managerStorage[spender].allowanceKey;
        uint256 newAllowance = $storage().allowance[spender][allowanceKey][currency] += byAmount;
        emit Lens_Account_AllowanceIncreased(spender, currency, newAllowance);
        return newAllowance;
    }

    function _decreaseAllowance(address spender, address currency, uint256 byAmount) internal returns (uint256) {
        return _decreaseAllowance({spender: spender, currency: currency, byAmount: byAmount, failOnUnderflow: false});
    }

    function _spendAllowance(address spender, address currency, uint256 amount) internal returns (uint256) {
        return _decreaseAllowance({spender: spender, currency: currency, byAmount: amount, failOnUnderflow: true});
    }

    function _decreaseAllowance(address spender, address currency, uint256 byAmount, bool failOnUnderflow)
        internal
        returns (uint256)
    {
        uint256 newAllowance = 0;
        uint256 allowanceKey = $storage().managerStorage[spender].allowanceKey;
        if ($storage().allowance[spender][allowanceKey][currency] < byAmount) {
            require(failOnUnderflow == false, Errors.InsufficientAllowance());
            $storage().allowance[spender][allowanceKey][currency] = 0;
        } else {
            newAllowance = $storage().allowance[spender][allowanceKey][currency] -= byAmount;
        }
        emit Lens_Account_AllowanceDecreased(spender, currency, newAllowance);
        return newAllowance;
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
        bool isMsgSenderOwner = _beforeExecuteTransaction();
        return _executeTransaction(isMsgSenderOwner, target, value, data);
    }

    function executeTransactions(Transaction[] calldata transactions)
        external
        payable
        override
        returns (bytes[] memory)
    {
        bool isMsgSenderOwner = _beforeExecuteTransaction();
        bytes[] memory returnData = new bytes[](transactions.length);
        for (uint256 i = 0; i < transactions.length; i++) {
            returnData[i] = _executeTransaction(
                isMsgSenderOwner, transactions[i].target, transactions[i].value, transactions[i].data
            );
        }
        return returnData;
    }

    function _beforeExecuteTransaction() internal returns (bool) {
        bool isMsgSenderOwner = msg.sender == owner();
        require(isMsgSenderOwner || $storage().managerStorage[msg.sender].canExecuteTransactions, Errors.NotAllowed());
        if (msg.value > 0 && !isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens) {
            _increaseAllowance(msg.sender, GHO, msg.value);
        }
        return isMsgSenderOwner;
    }

    function _executeTransaction(bool isMsgSenderOwner, address target, uint256 value, bytes calldata data)
        internal
        virtual
        returns (bytes memory)
    {
        if (data.length >= SELECTOR_BYTE_LENGTH) {
            _handleSpecificSelectorLogicBeforeCall(
                isMsgSenderOwner, target, value, bytes4(data[:SELECTOR_BYTE_LENGTH]), data[SELECTOR_BYTE_LENGTH:]
            );
        } else if (
            value > 0 && msg.value > 0 && !isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens
        ) {
            _spendAllowance(msg.sender, GHO, msg.value);
        }
        bytes memory returnData = target.handledcall(value, data);
        emit Lens_Account_TransactionExecuted(target, value, data, msg.sender);
        return returnData;
    }

    function _isERC20(address target) internal view returns (bool) {
        // We call isApprovedForAll to check if the method is present or not; we assume that if the call fails
        // then it's not an standard ERC-721 or ERC-1155 implementation, and very likely it is an ERC-20 one.
        bytes memory encodedCall = abi.encodeCall(IERC721.isApprovedForAll, (address(this), address(msg.sender)));
        (bool callSucceeded,) = target.staticcall(encodedCall);
        return callSucceeded == false;
    }

    /// NOTE: This approach is not ideal. We should switch to a denied-by-default strategy.
    /// Then, specific selectors must be enabled for specific contract addresses.
    /// This hints to use Access Control with scoped (address-based) Roles and Permissions.
    function _handleSpecificSelectorLogicBeforeCall(
        bool isMsgSenderOwner,
        address target,
        uint256 value,
        bytes4 selector,
        bytes calldata encodedParams
    ) internal {
        if (target == address(WGHO) && selector == bytes4(keccak256("deposit()"))) {
            if (!isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens) {
                _spendAllowance(msg.sender, GHO, value);
                _increaseAllowance(msg.sender, WGHO, value);
            }
        } else if (target == address(WGHO) && selector == bytes4(keccak256("withdraw(uint256)"))) {
            (uint256 amount) = abi.decode(encodedParams, (uint256));
            if (!isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens) {
                _spendAllowance(msg.sender, WGHO, amount);
                _increaseAllowance(msg.sender, GHO, amount);
            }
        } else if (selector == bytes4(keccak256("transferFrom(address,address,uint256)"))) {
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (
                address from, uint256 amount, address to
            ) {
                if (_isERC20(target)) {
                    /**
                     * Until EIP-7702 is supported by ZkSync, we only allow `transferFrom` from the msg.sender.
                     * In other words, we only allow you to spend your own funds.
                     *
                     * This is to prevent owner/managers draining managers' funds in case infinite approval was granted.
                     *
                     * EIP-7702 will allow multi-calling from any account, allowing multi-step approval-requiring
                     * operations to be done as a single-tx.
                     */
                    require(from == msg.sender, Errors.NotAllowed());
                    if (!isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens) {
                        if (from == msg.sender && to == address(this)) {
                            _increaseAllowance(msg.sender, target, amount);
                        } else {
                            _spendAllowance(msg.sender, target, amount);
                        }
                    }
                } else {
                    require($storage().managerStorage[msg.sender].canTransferTokens, Errors.NotAllowed());
                }
            } catch {
                return;
            }
        } else if (
            selector == bytes4(keccak256("transfer(address,uint256)"))
                || selector == bytes4(keccak256("approve(address,uint256)"))
                || selector == bytes4(keccak256("increaseAllowance(address,uint256)"))
        ) {
            // Intentionally skipped decreaseAllowance case, allowing it for any manager, as emergency/safety mechanism
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (address, uint256 amount, address)
            {
                if (!isMsgSenderOwner && !$storage().managerStorage[msg.sender].canTransferTokens) {
                    _spendAllowance(msg.sender, target, amount);
                }
            } catch {
                return;
            }
        } else if (
            selector == bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
                || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
                || selector == bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))
                || selector == bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))
                || selector == bytes4(keccak256("setApprovalForAll(address,bool)"))
        ) {
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (address, uint256, address) {
                require(isMsgSenderOwner || $storage().managerStorage[msg.sender].canTransferTokens);
            } catch {
                return;
            }
        } else if (selector == IRequestBasedGroupRule.sendMembershipRequest.selector) {
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (address group, uint256, address) {
                $storage().didSendRequestToGroup[group] = true;
            } catch {
                return;
            }
        } else if (selector == IRequestBasedGroupRule.cancelMembershipRequest.selector) {
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (address group, uint256, address) {
                $storage().didSendRequestToGroup[group] = false;
            } catch {
                return;
            }
        } else if (selector == IGraph.follow.selector) {
            try this.abiDecodeForKnownSelectorHelper(selector, encodedParams) returns (address, uint256, address) {
                $storage().didFollowOnGraph[target] = true;
            } catch {
                return;
            }
        }
    }

    // Permissionless function to remove owners set as manager during migration, as that is an undesired state.
    function removeOwnerAsManager() external {
        address owner = owner();
        if (_isAccountManager(owner)) {
            _removeAccountManager(owner);
        }
    }

    // Permissionless function to remove accounts that set itself as manager, as that is an undesired state.
    function removeAccountAsManager() external {
        if (_isAccountManager(address(this))) {
            _removeAccountManager(address(this));
        }
    }

    function _addAccountManager(address accountManager, AccountManagerPermissions memory permissions) internal {
        require(!_isAccountManager(accountManager), Errors.RedundantStateChange());
        _validateAccountManagerPermissions(permissions);
        require(accountManager != owner(), Errors.InvalidParameter());
        require(accountManager != address(0), Errors.InvalidParameter());
        require(accountManager != address(this), Errors.InvalidParameter());
        $storage().managerStorage[accountManager].updatePermissionsTo(permissions);
        emit Lens_Account_AccountManagerAdded(accountManager, permissions);
    }

    function _removeAccountManager(address accountManager) internal {
        $storage().managerStorage[accountManager].clearPermissions();
        emit Lens_Account_AccountManagerRemoved(accountManager);
        _clearAllAllowances(accountManager);
    }

    // Receiver

    receive() external payable override {
        // NOTE: This way of funding does not increase allowance. You need to fund through executeTransaction(s) if you
        // want your allowance to be increased.
    }

    // Getters

    function canExecuteTransactions(address executor) external view override returns (bool) {
        return $storage().managerStorage[executor].canExecuteTransactions || executor == owner();
    }

    function isAccountManager(address accountManager) external view override returns (bool) {
        return _isAccountManager(accountManager);
    }

    function canSetMetadataURI(address executor) external view override returns (bool) {
        return $storage().managerStorage[executor].canSetMetadataURI || executor == owner();
    }

    function getAccountManagerPermissions(address accountManager)
        external
        view
        override
        returns (AccountManagerPermissions memory)
    {
        return $storage().managerStorage[accountManager].toAccountManagerPermissions();
    }

    function getAccountManagerAllowance(address accountManager, address currency)
        external
        view
        override
        returns (uint256)
    {
        AccountManagerStorage memory managerStorage = $storage().managerStorage[accountManager];
        if (managerStorage.canTransferTokens) {
            return type(uint256).max;
        } else {
            return $storage().allowance[accountManager][managerStorage.allowanceKey][currency];
        }
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function _transferOwnership(address newOwner) internal override {
        require(newOwner != address(this), Errors.InvalidParameter());
        if (_isAccountManager(newOwner)) {
            _removeAccountManager(newOwner);
        }
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
