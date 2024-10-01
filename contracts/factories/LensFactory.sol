// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "./../primitives/access-control/IRoleBasedAccessControl.sol";
import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {Community} from "./../primitives/community/Community.sol";
import {OwnerOnlyAccessControl} from "./../primitives/access-control/OwnerOnlyAccessControl.sol";
import {OwnerAdminAccessControl} from "./../primitives/access-control/OwnerAdminAccessControl.sol";
import {RuleConfiguration} from "./../types/Types.sol";
import {CommunityFactory} from "./CommunityFactory.sol";
import {FeedFactory} from "./FeedFactory.sol";
import {GraphFactory} from "./GraphFactory.sol";
import {UsernameFactory} from "./UsernameFactory.sol";

struct RoleConfiguration {
    uint256 roleId;
    address[] accounts;
}

struct AccessConfiguration {
    uint256 resourceId;
    address resourceLocation;
    uint256 roleId;
    IRoleBasedAccessControl.AccessPermission accessPermission;
}

contract LensFactory {
    CommunityFactory internal immutable COMMUNITY_FACTORY;
    FeedFactory internal immutable FEED_FACTORY;
    GraphFactory internal immutable GRAPH_FACTORY;
    UsernameFactory internal immutable USERNAME_FACTORY;
    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor(
        CommunityFactory communityFactory,
        FeedFactory feedFactory,
        GraphFactory graphFactory,
        UsernameFactory usernameFactory
    ) {
        COMMUNITY_FACTORY = communityFactory;
        FEED_FACTORY = feedFactory;
        GRAPH_FACTORY = graphFactory;
        USERNAME_FACTORY = usernameFactory;
        _factoryOwnedAccessControl = new OwnerOnlyAccessControl({owner: address(this)});
    }

    function deployCommunity(
        string memory metadataURI,
        RoleConfiguration[] calldata roleConfigs,
        AccessConfiguration[] calldata accessConfigs,
        RuleConfiguration[] calldata rules
    ) external returns (address) {
        return COMMUNITY_FACTORY.deploy(metadataURI, _deployAccessControl(roleConfigs, accessConfigs), rules);
    }

    function deployFeed(
        string memory metadataURI,
        RoleConfiguration[] calldata roleConfigs,
        AccessConfiguration[] calldata accessConfigs,
        RuleConfiguration[] calldata rules
    ) external returns (address) {
        return FEED_FACTORY.deploy(metadataURI, _deployAccessControl(roleConfigs, accessConfigs), rules);
    }

    function deployGraph(
        string memory metadataURI,
        RoleConfiguration[] calldata roleConfigs,
        AccessConfiguration[] calldata accessConfigs,
        RuleConfiguration[] calldata rules
    ) external returns (address) {
        return GRAPH_FACTORY.deploy(metadataURI, _deployAccessControl(roleConfigs, accessConfigs), rules);
    }

    function deployUsername(
        string memory namespace,
        string memory metadataURI,
        RoleConfiguration[] calldata roleConfigs,
        AccessConfiguration[] calldata accessConfigs,
        RuleConfiguration[] calldata rules
    ) external returns (address) {
        return USERNAME_FACTORY.deploy(namespace, metadataURI, _deployAccessControl(roleConfigs, accessConfigs), rules);
    }

    function _deployAccessControl(
        RoleConfiguration[] calldata roleConfigs,
        AccessConfiguration[] calldata accessConfigs
    ) internal returns (IRoleBasedAccessControl) {
        IRoleBasedAccessControl accessControl = new OwnerAdminAccessControl({owner: address(this)}); // TODO: We need the new access control implementation to be done!
        for (uint256 i = 0; i < roleConfigs.length; i++) {
            for (uint256 j = 0; j < roleConfigs[i].accounts.length; j++) {
                accessControl.grantRole(roleConfigs[i].accounts[j], roleConfigs[i].roleId);
            }
        }
        for (uint256 i = 0; i < accessConfigs.length; i++) {
            if (accessConfigs[i].resourceLocation == address(0)) {
                accessControl.setGlobalAccess(
                    accessConfigs[i].roleId, accessConfigs[i].resourceId, accessConfigs[i].accessPermission, ""
                );
            } else {
                accessControl.setScopedAccess(
                    accessConfigs[i].roleId,
                    accessConfigs[i].resourceLocation,
                    accessConfigs[i].resourceId,
                    accessConfigs[i].accessPermission,
                    ""
                );
            }
        }
        return accessControl;
    }
}