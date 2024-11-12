// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../contracts/primitives/graph/IGraphRule.sol";

contract MockGraphRule is IGraphRule {
    bool public processFollowRulesChangeCalled;
    address public lastAccount;
    IFollowRule public lastFollowRules;
    bytes public lastData;

    // For processFollow
    bool public processFollowCalled;
    address public lastFollowerAccount;
    address public lastTargetAccount;
    uint256 public lastFollowId;
    bytes public lastGraphRulesData;

    // For processUnfollow
    bool public processUnfollowCalled;
    address public lastUnfollowerAccount;
    address public lastUnfollowedAccount;
    uint256 public lastUnfollowId;
    bytes public lastUnfollowGraphRulesData;

    event ProcessFollowCalled(address followerAccount, address targetAccount, uint256 followId, bytes graphRulesData);
    event ProcessUnfollowCalled(
        address unfollowerAccount, address unfollowedAccount, uint256 unfollowId, bytes graphRulesData
    );
    event ProcessFollowRulesChangeCalled(address account, IFollowRule followRules, bytes data);
    event ProcessBlockCalled(address account, bytes data);
    event ProcessUnblockCalled(address account, bytes data);

    function processFollowRulesChange(address account, IFollowRule followRules, bytes calldata data)
        external
        override
    {
        processFollowRulesChangeCalled = true;
        lastAccount = account;
        lastFollowRules = followRules;
        lastData = data;
        emit ProcessFollowRulesChangeCalled(account, followRules, data);
    }

    function processFollow(
        address,
        address followerAccount,
        address targetAccount,
        uint256 followId,
        bytes calldata graphRulesData
    ) external override {
        processFollowCalled = true;
        lastFollowerAccount = followerAccount;
        lastTargetAccount = targetAccount;
        lastFollowId = followId;
        lastGraphRulesData = graphRulesData;
        emit ProcessFollowCalled(followerAccount, targetAccount, followId, graphRulesData);
    }

    function processUnfollow(
        address,
        address unfollowerAccount,
        address unfollowedAccount,
        uint256 unfollowId,
        bytes calldata graphRulesData
    ) external override {
        processUnfollowCalled = true;
        lastUnfollowerAccount = unfollowerAccount;
        lastUnfollowedAccount = unfollowedAccount;
        lastUnfollowId = unfollowId;
        lastUnfollowGraphRulesData = graphRulesData;
        emit ProcessUnfollowCalled(unfollowerAccount, unfollowedAccount, unfollowId, graphRulesData);
    }

    function processBlock(address account, bytes calldata data) external override {
        emit ProcessBlockCalled(account, data);
    }

    function processUnblock(address account, bytes calldata data) external override {
        emit ProcessUnblockCalled(account, data);
    }

    function configure(bytes calldata data) external override {}
}
