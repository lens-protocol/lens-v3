// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {Events} from "contracts/core/types/Events.sol";
import {RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";

contract GroupKicker {
    // The only address that is allowed to call the kick function
    BanMemberGroupRule internal immutable _banMemberGroupRule;

    constructor(address banMemberGroupRule) {
        _banMemberGroupRule = BanMemberGroupRule(banMemberGroupRule);
        emit Events.Lens_Contract_Deployed({
            contractType: "lens.contract.GroupKicker",
            flavour: "lens.contract.GroupKicker"
        });
    }

    function kick(
        address group,
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external {
        require(msg.sender == address(_banMemberGroupRule), "Only the BanMemberGroupRule can call this function");
        require(_banMemberGroupRule.isMemberBanned(group, account), "Account is not banned");
        IGroup(group).removeMember(account, customParams, ruleProcessingParams);
    }

    function getBanMemberGroupRule() external view returns (address) {
        return address(_banMemberGroupRule);
    }
}
