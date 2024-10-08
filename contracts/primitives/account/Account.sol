// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DefaultAccount} from "./DefaultAccount.sol";
import {Events} from "./../../types/Events.sol";
import {IAccount} from "./IAccount.sol";

contract Account is IAccount, DefaultAccount {
    mapping(address => bool) public accountManagers; // TODO: Add permissions etc when needed
    address public immutable owner; // TODO: Transfer ownership is not possible right now
    string public metadataURI; // TODO: Add getter/setter/internal etc

    constructor(address _owner, string memory _metadataURI, address[] memory _accountManagers) {
        owner = _owner;
        metadataURI = _metadataURI;
        emit Lens_Account_MetadataURISet(_metadataURI);
        for (uint256 i = 0; i < _accountManagers.length; i++) {
            accountManagers[_accountManagers[i]] = true;
            emit Lens_Account_AccountManagerAdded(_accountManagers[i]);
        }
        emit Events.Lens_Contract_Deployed("account", "lens.account", "account", "lens.account");
    }

    function addAccountManager(address _accountManager) external override {
        require(msg.sender == owner, "NOT_AUTHORIZED");
        accountManagers[_accountManager] = true;
        emit Lens_Account_AccountManagerAdded(_accountManager);
    }

    function removeAccountManager(address _accountManager) external override {
        require(msg.sender == owner, "NOT_AUTHORIZED");
        delete accountManagers[_accountManager];
        emit Lens_Account_AccountManagerRemoved(_accountManager);
    }

    function setMetadataURI(string calldata _metadataURI) external override {
        require(msg.sender == owner, "NOT_AUTHORIZED");
        metadataURI = _metadataURI;
        emit Lens_Account_MetadataURISet(_metadataURI);
    }

    function _isValidSignature(bytes32 _hash, bytes memory _signature) internal view override returns (bool) {
        address recoveredAddress = _recoverAddress(_hash, _signature);
        if (recoveredAddress == address(0)) return false;
        if (recoveredAddress == owner) return true;
        if (accountManagers[recoveredAddress]) {
            // TODO: Can add additional require's here if needed (like checking which address or function is called)
            // (but then need Transaction object in this function)
            return true;
        } else {
            return false;
        }
    }
}
