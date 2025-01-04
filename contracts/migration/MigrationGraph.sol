// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {GraphCore as Core} from "./../core/primitives/graph/GraphCore.sol";
import {Graph} from "./../core/primitives/graph/Graph.sol";
import {RuleProcessingParams, KeyValue} from "./../core/types/Types.sol";
import {IAccessControl} from "./../core/interfaces/IAccessControl.sol";

/**
 * Special Graph implementation to allow data migrations from Lens V2 to Lens V3
 */
contract MigrationGraph is Graph {
    function follow(
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams,
        KeyValue[] calldata extraData
    ) external override returns (uint256) {
        (uint256 followId, uint256 timestamp) = abi.decode(customParams[0].value, (uint256, uint256));
        Core._follow(followerAccount, accountToFollow, followId, timestamp);
        emit Lens_Graph_Followed(
            followerAccount,
            accountToFollow,
            followId,
            customParams,
            graphRulesProcessingParams,
            followRulesProcessingParams,
            address(0),
            extraData
        );
        return followId;
    }
}
