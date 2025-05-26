// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {NATIVE_TOKEN, BPS_MAX} from "contracts/core/types/Constants.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {ActionHub} from "contracts/extensions/actions/ActionHub.sol";
import {MockFeed} from "test/helpers/MockFeed.sol";

/// @custom:keccak lens.param.amount
bytes32 constant PARAM__TIP_AMOUNT = 0xc8a06abcb0f2366f32dc2741bdf075c3215e3108918311ec0ac742f1ffd37f49;
/// @custom:keccak lens.param.token
bytes32 constant PARAM__TIP_TOKEN = 0xee737c77be2981e91c179485406e6d793521b20aca5e2137b6c497949a74bc94;

contract TippingAccountActionTest is Test, BaseDeployments {
    address mockFeed;

    function setUp() public override {
        mockFeed = address(new MockFeed());
        super.setUp();
    }

    function testCanPostTipNative_woReferrals(uint256 msgValue, address account) public {
        vm.assume(account != address(0));
        vm.assume(account != address(TREASURY_ADDRESS));
        vm.assume(account.code.length == 0);
        vm.assume(uint160(account) > type(uint16).max); // skip system contracts
        assumeNotForgeAddress(account);

        msgValue = msgValue % (1 << 95);
        vm.assume(msgValue > 0);
        vm.deal(address(this), msgValue);

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, account);

        KeyValue[] memory params = _toKeyValueArray(
            KeyValue({key: PARAM__TIP_AMOUNT, value: abi.encode(msgValue)}),
            KeyValue({key: PARAM__TIP_TOKEN, value: abi.encode(NATIVE_TOKEN)})
        );

        uint256 accountBalanceBefore = account.balance;
        uint256 treasuryBalanceBefore = address(TREASURY_ADDRESS).balance;

        ActionHub(actionHub).executePostAction{value: msgValue}(address(tippingPostAction), mockFeed, postId, params);

        uint256 accountBalanceAfter = account.balance;
        uint256 treasuryBalanceAfter = address(TREASURY_ADDRESS).balance;

        uint256 expectedTreasuryBalanceChange = msgValue * TREASURY_FEE_BPS / BPS_MAX;
        uint256 expectedAccountBalanceChange = msgValue - expectedTreasuryBalanceChange;

        assertEq(accountBalanceAfter, accountBalanceBefore + expectedAccountBalanceChange, "Account balance mismatch");
        assertEq(
            treasuryBalanceAfter, treasuryBalanceBefore + expectedTreasuryBalanceChange, "Treasury balance mismatch"
        );
    }
}
