// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RuleChange, RuleSelectorChange, RuleConfigurationChange, KeyValue, Rule} from "contracts/core/types/Types.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {Post} from "contracts/core/interfaces/IFeed.sol";

/// @dev Run this script using the following command:
///   forge script script/Query.s.sol --rpc-url https://api.lens.matterhosted.dev/ --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract Query is Script {
    address constant LENS_GLOBAL_NAMESPACE = address(0x1aA55B9042f08f45825dC4b651B64c9F98Af4615);
    address constant LENS_GLOBAL_FEED = address(0xcB5E109FFC0E15565082d78E68dDDf2573703580);
    address constant LENS_GLOBAL_GRAPH = address(0x433025d9718302E7B2e1853D712d96F00764513F);

    function testQuery() public {
        // Prevents being counted in Foundry Coverage
    }

    function _generatePostId(address author, uint256 authorPostSequentialId) internal view returns (uint256) {
        return uint256(keccak256(abi.encode("evm:", 271, LENS_GLOBAL_FEED, author, authorPostSequentialId)));
    }

    function run() external {
        console.log("ChainID: ", block.chainid);
        address author = address(0x2aa01F5cDF6403B3b53826e7798790069185bE2F);
        uint256 postCount = IFeed(LENS_GLOBAL_FEED).getPostCount(author);
        console.log("Post Count: ", postCount);
        for (uint256 i = 0; i < postCount + 5; i++) {
            uint256 postId = _generatePostId(author, i);
            console.log("Sequence: ", i);
            console.log("Post ID: ", postId);
            bool exists = IFeed(LENS_GLOBAL_FEED).postExists(postId);
            if (exists) {
                console.log("Exists");
                Post memory post = IFeed(LENS_GLOBAL_FEED).getPost(postId);
                console.log("URI: ", post.contentURI);
            } else {
                console.log("DO NOT exist");
            }
        }
    }
}
