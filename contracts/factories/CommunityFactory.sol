// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {Community} from "./../primitives/community/Community.sol";
import {OwnerOnlyAccessControl} from "./../primitives/access-control/OwnerOnlyAccessControl.sol";
import {RuleConfiguration, DataElement} from "./../types/Types.sol";

contract CommunityFactory {
    event Lens_CommunityFactory_Deployment(address indexed community);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new OwnerOnlyAccessControl({owner: address(this)});
    }

    function deployCommunity(
        string memory metadataURI,
        IAccessControl accessControl,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData
    ) external returns (address) {
        Community community = new Community(metadataURI, _factoryOwnedAccessControl);
        community.addCommunityRules(rules);
        community.setExtraData(extraData);
        community.setAccessControl(accessControl);
        emit Lens_CommunityFactory_Deployment(address(community));
        return address(community);
    }
}
