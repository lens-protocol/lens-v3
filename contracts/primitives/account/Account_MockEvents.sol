// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccountFactory {
    event Lens_Factory_AccountCreated(address indexed account, address indexed createdBy);
}

contract Account {
    event Lens_Account_ManagerAdded(address indexed manager); // TODO: We might have AccessControl on our Managers
    event Lens_Account_ManagerRemoved(address indexed manager);
}
