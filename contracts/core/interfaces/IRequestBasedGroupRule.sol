// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

interface IRequestBasedGroupRule is IGroupRule {
    function sendMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata params) external;

    function cancelMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata params) external;
}
