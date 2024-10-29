// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {Username} from "./../primitives/username/Username.sol";
import {RoleBasedAccessControl} from "./../primitives/access-control/RoleBasedAccessControl.sol";
import {RuleConfiguration, DataElement} from "./../types/Types.sol";
import {ITokenURIProvider} from "./../primitives/base/ITokenURIProvider.sol";

contract UsernameFactory {
    event Lens_UsernameFactory_Deployment(address indexed username, string namespace);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    function deployUsername(
        string memory namespace,
        address metadataURISource,
        string memory metadataURI,
        IAccessControl accessControl,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) external returns (address) {
        Username username = new Username(
            namespace, metadataURISource, metadataURI, _factoryOwnedAccessControl, nftName, nftSymbol, tokenURIProvider
        );
        username.addUsernameRules(rules);
        username.setExtraData(extraData);
        username.setAccessControl(accessControl);
        emit Lens_UsernameFactory_Deployment(address(username), namespace);
        return address(username);
    }
}
