// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DefaultAccount} from "./DefaultAccount.sol";
import {Events} from "./../../types/Events.sol";
import {IAccount} from "./IAccount.sol";

contract Account is IAccount, DefaultAccount {
    mapping(address => bool) public profileManagers;
    address public immutable owner;
    string public metadataURI;

    constructor(address _owner, string memory _metadataURI, address[] memory _profileManagers) {
        owner = _owner;
        metadataURI = _metadataURI;
        emit Lens_Account_MetadataURISet(_metadataURI);
        for (uint256 i = 0; i < _profileManagers.length; i++) {
            profileManagers[_profileManagers[i]] = true;
            emit Lens_Account_ProfileManagerAdded(_profileManagers[i]);
        }
        emit Events.Lens_Contract_Deployed("account", "lens.account", "account", "lens.account");
    }

    function addProfileManager(address _profileManager) external override {
        require(msg.sender == address(this), "NOT_AUTHORIZED");
        profileManagers[_profileManager] = true;
        emit Lens_Account_ProfileManagerAdded(_profileManager);
    }

    function removeProfileManager(address _profileManager) external override {
        require(msg.sender == address(this), "NOT_AUTHORIZED");
        delete profileManagers[_profileManager];
        emit Lens_Account_ProfileManagerRemoved(_profileManager);
    }

    function setMetadataURI(string calldata _metadataURI) external override {
        metadataURI = _metadataURI;
        emit Lens_Account_MetadataURISet(_metadataURI);
    }

    function _isValidSignature(bytes32 _hash, bytes memory _signature) internal view override returns (bool) {
        address recoveredAddress = _recoverAddress(_hash, _signature);
        if (recoveredAddress == address(0)) return false;
        if (recoveredAddress == owner) return true;
        if (profileManagers[recoveredAddress]) {
            // Can add additional require's here if needed (like checking which address or function is called)
            // (but then need Transaction object in this function)
            return true;
        } else {
            return false;
        }
    }
}
