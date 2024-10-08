// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IDefaultAccount} from "./interfaces/IDefaultAccount.sol";

interface IAccount is IDefaultAccount {
    event Lens_Account_AccountManagerAdded(address indexed accountManager);
    event Lens_Account_AccountManagerRemoved(address indexed accountManager);
    event Lens_Account_MetadataURISet(string metadataURI);

    function addAccountManager(address _accountManager) external;
    function removeAccountManager(address _accountManager) external;
    function setMetadataURI(string calldata _metadataURI) external;
}
