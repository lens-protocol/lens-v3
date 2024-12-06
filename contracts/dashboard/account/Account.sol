// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Events} from "./../../core/types/Events.sol";
import {IAccount, AccountManagerPermissions} from "./IAccount.sol";
import {SourceStamp} from "./../../core/types/Types.sol";
import {ISource} from "./../../core/interfaces/ISource.sol";

contract Account is IAccount, Ownable, IERC721Receiver {
    // TODO: Think how long the timelock should be and should it be configurable
    uint256 constant SPENDING_TIMELOCK = 1 hours;

    mapping(address => string) internal _metadataURI; // TODO: Add getter/setter/internal etc
    mapping(address => AccountManagerPermissions) internal _accountManagerPermissions; // TODO: Add getter/setter/internal etc
    uint256 internal _allowNonOwnerSpendingTimestamp; // TODO: Think of a better name

    constructor(
        address owner,
        string memory metadataURI,
        address[] memory accountManagers,
        AccountManagerPermissions[] memory accountManagerPermissions,
        SourceStamp memory sourceStamp
    ) Ownable() {
        _metadataURI[sourceStamp.source] = metadataURI;
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        for (uint256 i = 0; i < accountManagers.length; i++) {
            _accountManagerPermissions[accountManagers[i]] = accountManagerPermissions[i];
            emit Lens_Account_AccountManagerAdded(accountManagers[i], accountManagerPermissions[i]);
        }
        _transferOwnership(owner);
        emit Lens_Account_MetadataURISet(metadataURI, sourceStamp.source);
        emit Events.Lens_Contract_Deployed("account", "lens.account", "account", "lens.account");
    }

    // Owner Only functions

    function allowNonOwnerSpending(bool allow) external onlyOwner {
        if (allow) {
            require(_allowNonOwnerSpendingTimestamp == 0, "Non-Owner Spending Already Allowed");
            _allowNonOwnerSpendingTimestamp = block.timestamp;
        } else {
            require(_allowNonOwnerSpendingTimestamp > 0, "Non-Owner Spending Already Not Allowed");
            delete _allowNonOwnerSpendingTimestamp;
        }
        emit Lens_Account_AllowNonOwnerSpending(allow, allow ? block.timestamp : 0);
    }

    function addAccountManager(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require(!_accountManagerPermissions[accountManager].canExecuteTransactions, "Account manager already exists");
        require(accountManager != owner(), "Cannot add owner as account manager");
        require(accountManager != address(0), "Cannot add zero address as account manager");
        _accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerAdded(accountManager, accountManagerPermissions);
    }

    function removeAccountManager(address accountManager) external override onlyOwner {
        require(_accountManagerPermissions[accountManager].canExecuteTransactions, "Account manager already exists");
        delete _accountManagerPermissions[accountManager];
        emit Lens_Account_AccountManagerRemoved(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyOwner {
        require(_accountManagerPermissions[accountManager].canExecuteTransactions, "Account manager does not exist");
        require(accountManagerPermissions.canExecuteTransactions, "Cannot remove execution permissions");
        _accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function getAccountManagerPermissions(address accountManager)
        external
        view
        override
        returns (AccountManagerPermissions memory)
    {
        return _accountManagerPermissions[accountManager];
    }

    function canExecuteTransactions(address executor) external view override returns (bool) {
        return _accountManagerPermissions[executor].canExecuteTransactions || executor == owner();
    }

    function setMetadataURI(string calldata metadataURI, SourceStamp calldata sourceStamp) external override {
        if (msg.sender != owner()) {
            require(_accountManagerPermissions[msg.sender].canSetMetadataURI, "No permissions to set metadata URI");
        }
        _metadataURI[sourceStamp.source] = metadataURI;
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Account_MetadataURISet(metadataURI, sourceStamp.source);
    }

    function getMetadataURI(address source) external view override returns (string memory) {
        return _metadataURI[source];
    }

    function executeTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable override returns (bytes memory) {
        if (msg.sender != owner()) {
            require(
                _accountManagerPermissions[msg.sender].canExecuteTransactions, "No permissions to execute transactions"
            );
            if (value > 0) {
                require(
                    _accountManagerPermissions[msg.sender].canTransferNative, "No permissions to transfer native tokens"
                );
            }
            if (_isTransferRelatedSelector(bytes4(data[:4]))) {
                require(
                    _allowNonOwnerSpendingTimestamp > 0
                        && block.timestamp - _allowNonOwnerSpendingTimestamp > SPENDING_TIMELOCK,
                    "Spender Lock ON: Non-owner spending not allowed"
                );
                require(_accountManagerPermissions[msg.sender].canTransferTokens, "No permissions to transfer tokens");
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
