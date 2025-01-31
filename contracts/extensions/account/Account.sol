// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IAccount, AccountManagerPermissions, Transaction} from "contracts/extensions/account/IAccount.sol";
import {SourceStamp, KeyValue} from "contracts/core/types/Types.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract Account is IAccount, Initializable, Ownable, ExtraStorageBased, MetadataBased, ERC1155Holder, ERC721Holder {
    using CallLib for address;

    // In a future Account version/upgrade this could be configurable by the owner.
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
        for (uint256 i = 0; i < accountManagers.length; i++) {
            $storage().accountManagerPermissions[accountManagers[i]] = accountManagerPermissions[i];
            emit Lens_Account_AccountManagerAdded(accountManagers[i], accountManagerPermissions[i]);
        }
        _decodeAndSetExtraData(extraData);
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

    // Owner Only functions

    function allowNonOwnerSpending(bool allow) external onlyOwner {
        if (allow) {
            require($storage().allowNonOwnerSpendingTimestamp == 0, Errors.RedundantStateChange());
            $storage().allowNonOwnerSpendingTimestamp = block.timestamp;
        } else {
            require($storage().allowNonOwnerSpendingTimestamp > 0, Errors.RedundantStateChange());
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
            !$storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.RedundantStateChange()
        );
        require(accountManager != owner(), Errors.InvalidParameter());
        require(accountManager != address(0), Errors.InvalidParameter());
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerAdded(accountManager, accountManagerPermissions);
    }

    function removeAccountManager(address accountManager) external override onlyOwner {
        require(
            $storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.RedundantStateChange()
        );
        delete $storage().accountManagerPermissions[accountManager];
        emit Lens_Account_AccountManagerRemoved(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require($storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.InvalidParameter());
        require(accountManagerPermissions.canExecuteTransactions, Errors.InvalidParameter());
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external onlyOwner {
        _decodeAndSetExtraData(extraDataToSet);
    }

    function executeTransaction(address target, uint256 value, bytes calldata data)
        external
        payable
        override
        returns (bytes memory)
    {
        require(
            msg.sender == owner() || $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
            Errors.NotAllowed()
        );
        return _executeTransaction(target, value, data);
    }

    function executeTransactions(Transaction[] calldata transactions)
        external
        payable
        override
        returns (bytes[] memory)
    {
        require(
            msg.sender == owner() || $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
            Errors.NotAllowed()
        );
        bytes[] memory returnData = new bytes[](transactions.length);
        for (uint256 i = 0; i < transactions.length; i++) {
            returnData[i] = _executeTransaction(transactions[i].target, transactions[i].value, transactions[i].data);
        }
        return returnData;
    }

    function _executeTransaction(address target, uint256 value, bytes calldata data)
        internal
        virtual
        returns (bytes memory)
    {
        if (value > 0) {
            require($storage().accountManagerPermissions[msg.sender].canTransferNative, Errors.NotAllowed());
        }
        if (_isTransferRelatedSelector(bytes4(data[:4]))) {
            require(
                $storage().allowNonOwnerSpendingTimestamp > 0
                    && block.timestamp - $storage().allowNonOwnerSpendingTimestamp > SPENDING_TIMELOCK,
                Errors.NotAllowed()
            );
            require($storage().accountManagerPermissions[msg.sender].canTransferTokens, Errors.NotAllowed());
        }
        bytes memory returnData = target.handledcall(value, data);
        emit Lens_Account_TransactionExecuted(target, value, data, msg.sender);
        return returnData;
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
        return _getExtraStorage_Self(key);
    }

    function _decodeAndSetExtraData(KeyValue[] memory extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setExtraStorage_Self(extraDataToSet[i]);
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
