// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Account} from "./../primitives/account/Account.sol";

contract AccountFactory {
    event Lens_AccountFactory_Deployment(
        address indexed account, address indexed owner, string metadataURI, address[] profileManagers
    );

    function deployAccount(address owner, string calldata metadataURI, address[] calldata profileManagers)
        external
        returns (address)
    {
        Account account = new Account(owner, metadataURI, profileManagers);
        emit Lens_AccountFactory_Deployment(address(account), owner, metadataURI, profileManagers);
        return address(account);
    }
}
