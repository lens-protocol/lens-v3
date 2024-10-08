// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IDefaultAccount} from "./interfaces/IDefaultAccount.sol";

interface IAccount is IDefaultAccount {
    event Lens_Account_ProfileManagerAdded(address indexed profileManager);
    event Lens_Account_ProfileManagerRemoved(address indexed profileManager);
    event Lens_Account_MetadataURISet(string metadataURI);

    function addProfileManager(address _profileManager) external;
    function removeProfileManager(address _profileManager) external;
    function setMetadataURI(string calldata _metadataURI) external;
}
