// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";

import {AccessControlled} from "contracts/core/access/AccessControlled.sol";

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";

/// @dev Run this script using the following command:
///   forge script script/DeployAndSetAccessControls.s.sol --rpc-url https://api.lens.matterhosted.dev/ --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract DeployAndSetAccessControls is Script {
    uint256 constant PID__CHANGE_RULES = uint256(0x550b12ef6572134aefc5804fd2b13ab3d8451e067ad453f67afe134cffebd977);

    address constant LENS_GLOBAL_NAMESPACE = address(0x1aA55B9042f08f45825dC4b651B64c9F98Af4615);
    address constant LENS_GLOBAL_FEED = address(0xcB5E109FFC0E15565082d78E68dDDf2573703580);
    address constant LENS_GLOBAL_GRAPH = address(0x433025d9718302E7B2e1853D712d96F00764513F);

    address constant ACCESS_CONTROL_FACTORY = address(0x0d028419c270C2d366929f459418a4905D1B778F);

    function testDeployAndSetAccessControls() public {
        // Prevents being counted in Foundry Coverage
    }

    function run() external {
        uint256 pk = vm.envUint("WALLET_PRIVATE_KEY");

        address acOwner = address(0xaAFa8246dE0ae0e7b81125db325e9B39BED43B49);
        address[] memory acAdmins = new address[](1);
        acAdmins[0] = address(0x4018D03a0739a96c147E467F3BA6f8BE3F1F20e7);

        vm.startBroadcast(pk);

        IAccessControl namespaceAc =
            AccessControlFactory(ACCESS_CONTROL_FACTORY).deployOwnerAdminOnlyAccessControl(acOwner, acAdmins);
        console.log("[ OK ] - Namespace Access Control deployed at: ", address(namespaceAc));
        AccessControlled(LENS_GLOBAL_NAMESPACE).setAccessControl(namespaceAc);
        console.log("[ OK ] - Namespace Access Control set \n\n");

        IAccessControl feedAc =
            AccessControlFactory(ACCESS_CONTROL_FACTORY).deployOwnerAdminOnlyAccessControl(acOwner, acAdmins);
        console.log("[ OK ] - Feed Access Control deployed at: ", address(feedAc));
        AccessControlled(LENS_GLOBAL_FEED).setAccessControl(feedAc);
        console.log("[ OK ] - Feed Access Control set \n\n");

        IAccessControl graphAc =
            AccessControlFactory(ACCESS_CONTROL_FACTORY).deployOwnerAdminOnlyAccessControl(acOwner, acAdmins);
        console.log("[ OK ] - Graph Access Control deployed at: ", address(graphAc));
        AccessControlled(LENS_GLOBAL_GRAPH).setAccessControl(graphAc);
        console.log("[ OK ] - Graph Access Control set \n\n");

        vm.stopBroadcast();

        console.log("- - - - - - - -");

        address namespaceAcOwner = IOwnable(address(namespaceAc)).owner();
        address feedAcOwner = IOwnable(address(feedAc)).owner();
        address graphAcOwner = IOwnable(address(graphAc)).owner();

        bool ownerMatches = acOwner == namespaceAcOwner && namespaceAcOwner == feedAcOwner && feedAcOwner == graphAcOwner;

        if (ownerMatches) {
            console.log("[ OK ] - AC Owners match for all and it is ", acOwner);
        } else {
            console.log("[ ERROR ] - AC Owners do not match");
            console.log("       Namespace AC Owner: ", namespaceAcOwner);
            console.log("       Feed AC Owner: ", feedAcOwner);
            console.log("       Graph AC Owner: ", graphAcOwner);
        }

        bool hasAccess = IAccessControl(namespaceAc).hasAccess({
            account: acAdmins[0],
            contractAddress: LENS_GLOBAL_NAMESPACE,
            permissionId: PID__CHANGE_RULES
        });

        console.log("- - - - - - - -");

        if (hasAccess) {
            console.log("[ OK ] - AC Admin has access to change rules for namespace");
        } else {
            console.log("[ ERROR ] - AC Admin does not have access to change rules for namespace");
        }

        hasAccess = IAccessControl(feedAc).hasAccess({
            account: acAdmins[0],
            contractAddress: LENS_GLOBAL_FEED,
            permissionId: PID__CHANGE_RULES
        });

        if (hasAccess) {
            console.log("[ OK ] - AC Admin has access to change rules for feed");
        } else {
            console.log("[ ERROR ] - AC Admin does not have access to change rules for namespace");
        }

        hasAccess = IAccessControl(graphAc).hasAccess({
            account: acAdmins[0],
            contractAddress: LENS_GLOBAL_GRAPH,
            permissionId: PID__CHANGE_RULES
        });

        if (hasAccess) {
            console.log("[ OK ] - AC Admin has access to change rules for graph");
        } else {
            console.log("[ ERROR ] - AC Admin does not have access to change rules for namespace");
        }
    }
}
