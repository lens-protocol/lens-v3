// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IMigrationNamespace {
    function migration_force__setNameAndSymbol(string calldata name, string calldata symbol) external;
}

/// @dev Run this script using the following command:
///   forge script script/Namespace_SetNameAndSymbol.s.sol --rpc-url https://api.lens.matterhosted.dev/ --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract Namespace_SetNameAndSymbol is Script {
    address constant WHITELISTED_MULTICALL = address(0xC9A7A3762cC1073b40B19f7A333c046ce464e8Db);

    address constant LENS_GLOBAL_NAMESPACE = address(0x1aA55B9042f08f45825dC4b651B64c9F98Af4615);

    function testNamespace_SetNameAndSymbol() public {
        // Prevents being counted in Foundry Coverage
    }

    function run() external {
        uint256 whitelistedCallerPK = vm.envUint("WHITELISTED_CALLER_PK");

        string memory name = IERC721Metadata(LENS_GLOBAL_NAMESPACE).name();
        string memory symbol = IERC721Metadata(LENS_GLOBAL_NAMESPACE).symbol();

        console.log("[BEFORE] Name: %s", name);
        console.log("[BEFORE] Symbol: %s", symbol);

        console.log("Updating name and symbol...");

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = LENS_GLOBAL_NAMESPACE;
        calls[0].callData =
            abi.encodeCall(IMigrationNamespace.migration_force__setNameAndSymbol, ("Lens Usernames", "LU"));

        vm.startBroadcast(whitelistedCallerPK);

        IMulticall3(WHITELISTED_MULTICALL).aggregate(calls);

        vm.stopBroadcast();

        name = IERC721Metadata(LENS_GLOBAL_NAMESPACE).name();
        symbol = IERC721Metadata(LENS_GLOBAL_NAMESPACE).symbol();

        console.log("[AFTER] Name: %s", name);
        console.log("[AFTER] Symbol: %s", symbol);
    }
}
