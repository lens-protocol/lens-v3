// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAccount {
    event Lens_Account_AccountManagerAdded(address indexed accountManager);
    event Lens_Account_AccountManagerRemoved(address indexed accountManager);
    event Lens_Account_MetadataURISet(address indexed source, string metadataURI);
    event Lens_Account_OwnerTransferred(address indexed newOwner);
    event TransactionExecuted(address indexed to, uint256 value, bytes data, address indexed executor);

    function addAccountManager(address _accountManager) external;
    function removeAccountManager(address _accountManager) external;
    function setMetadataURI(address source, string calldata _metadataURI) external;
    function executeTransaction(address to, uint256 value, bytes calldata data) external payable;

    receive() external payable;
}
