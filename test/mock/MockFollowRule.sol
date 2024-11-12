// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../contracts/primitives/graph/IFollowRule.sol";

contract MockFollowRule is IFollowRule {
    bool public processFollowCalled;
    address public lastFollowerAccount;
    uint256 public lastFollowId;
    bytes public lastFollowRulesData;

    function processFollow(address, address followerAccount, uint256 followId, bytes calldata followRulesData)
        external
        override
    {
        processFollowCalled = true;
        lastFollowerAccount = followerAccount;
        lastFollowId = followId;
        lastFollowRulesData = followRulesData;
    }

    function configure(bytes calldata data) external override {}
}
