// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RuleChange, RuleSelectorChange, RuleConfigurationChange, KeyValue, Rule} from "contracts/core/types/Types.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";

/// @dev Run this script using the following command:
///   forge script script/MultiPoke.s.sol --rpc-url https://api.lens.matterhosted.dev/ --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract MultiPoke is Script {
    address constant LENS_GLOBAL_NAMESPACE = address(0x1aA55B9042f08f45825dC4b651B64c9F98Af4615);
    address constant LENS_GLOBAL_FEED = address(0xcB5E109FFC0E15565082d78E68dDDf2573703580);
    address constant LENS_GLOBAL_GRAPH = address(0x433025d9718302E7B2e1853D712d96F00764513F);

    address constant WHITELISTED_MULTICALL = address(0xC9A7A3762cC1073b40B19f7A333c046ce464e8Db);

    function testMultiPoke() public {
        // Prevents being counted in Foundry Coverage
    }

    function run() external {
        uint256 whitelistedCallerPK = vm.envUint("WHITELISTED_CALLER_PK");

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](3);

        calls[0].target = LENS_GLOBAL_NAMESPACE;
        calls[0].callData = abi.encodeCall(IMetadataBased.getMetadataURI, ());

        calls[1].target = LENS_GLOBAL_FEED;
        calls[1].callData = abi.encodeCall(IMetadataBased.getMetadataURI, ());

        calls[2].target = LENS_GLOBAL_GRAPH;
        calls[2].callData = abi.encodeCall(IMetadataBased.getMetadataURI, ());

        vm.startBroadcast(whitelistedCallerPK);

        IMulticall3(WHITELISTED_MULTICALL).aggregate(calls);

        vm.stopBroadcast();
    }
}
