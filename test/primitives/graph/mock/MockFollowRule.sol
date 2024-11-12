// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IFollowRule} from "../../../../contracts/primitives/graph/IFollowRule.sol";

contract MockFollowRule is IFollowRule {
    address public lastConfiguredAccount;
    string public lastConfig;
    address public lastFollowerAccount;
    address public lastAccountToFollow;
    uint256 public lastFollowId;
    bool public configurationWillFail = false;
    bool public shouldPass = true;

    function configure(address account, bytes calldata data) external override {
        require(!configurationWillFail, "Configuration failed");

        lastConfiguredAccount = account;
        lastConfig = abi.decode(data, (string));
    }

    function processFollow(address followerAccount, address accountToFollow, uint256 followId, bytes calldata)
        external
        override
    {
        require(shouldPass, "ProcessFollow failed");
        lastFollowerAccount = followerAccount;
        lastAccountToFollow = accountToFollow;
        lastFollowId = followId;
    }

    function setConfigurationWillFail(bool willFail) external {
        configurationWillFail = willFail;
    }

    function setShouldPass(bool _shouldPass) external {
        shouldPass = _shouldPass;
    }
}
