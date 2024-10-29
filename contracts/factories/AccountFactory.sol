// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Account} from "./../primitives/account/Account.sol";

contract AccountFactory {
    event Lens_AccountFactory_Deployment(
        address indexed account, address indexed owner, string metadataURI, address[] accountManagers
    );

    function deployAccount(
        address owner,
        address metadataURISource,
        string calldata metadataURI,
        address[] calldata accountManagers
    ) external returns (address) {
        // TODO: Make it a proxy
        Account account = new Account(owner, metadataURISource, metadataURI, accountManagers);
        emit Lens_AccountFactory_Deployment(address(account), owner, metadataURI, accountManagers);
        return address(account);
    }
}
