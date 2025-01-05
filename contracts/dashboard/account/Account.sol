// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Events} from "contracts/core/types/Events.sol";
import {IAccount, AccountManagerPermissions} from "contracts/dashboard/account/IAccount.sol";
import {SourceStamp, KeyValue} from "contracts/core/types/Types.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract Account is IAccount, Initializable, Ownable, IERC721Receiver, ExtraStorageBased, MetadataBased {
    // TODO: Think how long the timelock should be and should it be configurable
    uint256 constant SPENDING_TIMELOCK = 1 hours;

    struct Storage {
        mapping(address => AccountManagerPermissions) accountManagerPermissions;
        uint256 allowNonOwnerSpendingTimestamp;
    }

    /// @custom:keccak lens.storage.Account
    bytes32 constant STORAGE__ACCOUNT = 0xf08a5e3d2dd76739ff9f91dc2ff8af2860b120d00f7938b9baa4607e3fee9019;

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
        KeyValue[] memory extraData
    ) external initializer {
        _initialize(metadataURI, accountManagers, accountManagerPermissions, sourceStamp, extraData);
        _transferOwnership(owner);
    }

    function _initialize(
        string memory metadataURI,
        address[] memory accountManagers,
        AccountManagerPermissions[] memory accountManagerPermissions,
        SourceStamp memory sourceStamp,
        KeyValue[] memory extraData
    ) internal {
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        for (uint256 i = 0; i < accountManagers.length; i++) {
            $storage().accountManagerPermissions[accountManagers[i]] = accountManagerPermissions[i];
            emit Lens_Account_AccountManagerAdded(accountManagers[i], accountManagerPermissions[i]);
        }
        _decodeAndSetExtraData(extraData);
        _setMetadataURI(metadataURI);
        // _emitPIDs();
        emit Events.Lens_Contract_Deployed("account", "lens.account", "account", "lens.account");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Account_MetadataURISet(metadataURI);
    }

    // TODO: Should we replace setMetadataURI with extraData? Cause here it looks like _setPrimitiveExtraDataByUser case
    function setMetadataURI(string calldata metadataURI, SourceStamp calldata sourceStamp) external override {
        if (msg.sender != owner()) {
            require(
                $storage().accountManagerPermissions[msg.sender].canSetMetadataURI, "No permissions to set metadata URI"
            );
        }
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
            _setMetadataURI(metadataURI, sourceStamp.source);
            emit Lens_Account_MetadataURISet(metadataURI, sourceStamp.source);
        } else {
            _setMetadataURI(metadataURI);
            emit Lens_Account_MetadataURISet(metadataURI, address(this));
        }
    }

    // Owner Only functions

    function allowNonOwnerSpending(bool allow) external onlyOwner {
        if (allow) {
            require($storage().allowNonOwnerSpendingTimestamp == 0, "Non-Owner Spending Already Allowed");
            $storage().allowNonOwnerSpendingTimestamp = block.timestamp;
        } else {
            require($storage().allowNonOwnerSpendingTimestamp > 0, "Non-Owner Spending Already Not Allowed");
            delete $storage().allowNonOwnerSpendingTimestamp;
        }
        emit Lens_Account_AllowNonOwnerSpending(allow, allow ? block.timestamp : 0);
    }

    function addAccountManager(address accountManager, AccountManagerPermissions calldata accountManagerPermissions)
        external
        override
        onlyOwner
    {
        require(
            !$storage().accountManagerPermissions[accountManager].canExecuteTransactions,
            "Account manager already exists"
        );
        require(accountManager != owner(), "Cannot add owner as account manager");
        require(accountManager != address(0), "Cannot add zero address as account manager");
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerAdded(accountManager, accountManagerPermissions);
    }

    function removeAccountManager(address accountManager) external override onlyOwner {
        require(
            $storage().accountManagerPermissions[accountManager].canExecuteTransactions, "Account manager already exists"
        );
        delete $storage().accountManagerPermissions[accountManager];
        emit Lens_Account_AccountManagerRemoved(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require(
            $storage().accountManagerPermissions[accountManager].canExecuteTransactions, "Account manager does not exist"
        );
        require(accountManagerPermissions.canExecuteTransactions, "Cannot remove execution permissions");
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external onlyOwner {
        _decodeAndSetExtraData(extraDataToSet);
    }

    function executeTransaction(address to, uint256 value, bytes calldata data)
        external
        payable
        override
        returns (bytes memory)
    {
        if (msg.sender != owner()) {
            require(
                $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
                "No permissions to execute transactions"
            );
            if (value > 0) {
                require(
                    $storage().accountManagerPermissions[msg.sender].canTransferNative,
                    "No permissions to transfer native tokens"
                );
            }
            if (_isTransferRelatedSelector(bytes4(data[:4]))) {
                require(
                    $storage().allowNonOwnerSpendingTimestamp > 0
                        && block.timestamp - $storage().allowNonOwnerSpendingTimestamp > SPENDING_TIMELOCK,
                    "Spender Lock ON: Non-owner spending not allowed"
                );
                require(
                    $storage().accountManagerPermissions[msg.sender].canTransferTokens,
                    "No permissions to transfer tokens"
                );
            }
        }
        (bool success, bytes memory ret) = to.call{value: value}(data);
        if (!success) {
            assembly {
                // Equivalent to reverting with the returned error selector if the length is not zero.
                let length := mload(ret)
                if iszero(iszero(length)) { revert(add(ret, 32), length) }
            }
        }
        emit Lens_Account_TransactionExecuted(to, value, data, msg.sender);
        return ret;
    }

    receive() external payable override {}

    function canExecuteTransactions(address executor) external view override returns (bool) {
        return $storage().accountManagerPermissions[executor].canExecuteTransactions || executor == owner();
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
        return _getPrimitiveExtraData(key);
    }

    function _decodeAndSetExtraData(KeyValue[] memory extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setPrimitiveExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Account_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Account_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Account_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
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
            || selector == bytes4(keccak256("setApprovalForAll(address,bool)"));
    }

    function _transferOwnership(address newOwner) internal override {
        super._transferOwnership(newOwner);
        emit Lens_Account_OwnerTransferred(newOwner);
    }

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
