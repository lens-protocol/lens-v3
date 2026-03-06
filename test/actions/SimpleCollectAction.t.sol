// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {NATIVE_TOKEN, BPS_MAX} from "contracts/core/types/Constants.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {ActionHub} from "contracts/extensions/actions/ActionHub.sol";
import {RecipientData} from "contracts/core/types/Types.sol";
import {Post, IFeed} from "contracts/core/interfaces/IFeed.sol";
import {MockFeed} from "test/mocks/MockFeed.sol";
import {LensCollectedPost} from "contracts/actions/post/collect/LensCollectedPost.sol";
import {CollectActionData} from "contracts/actions/post/collect/ISimpleCollectAction.sol";
import {MockSimpleCollectAction} from "test/mocks/MockSimpleCollectAction.sol";
import {MockLegacyLensCollectedPost} from "test/mocks/MockLegacyLensCollectedPost.sol";
import {Errors} from "contracts/core/types/Errors.sol";

/// @custom:keccak lens.param.amount
bytes32 constant PARAM__AMOUNT = 0xc8a06abcb0f2366f32dc2741bdf075c3215e3108918311ec0ac742f1ffd37f49;
/// @custom:keccak lens.param.token
bytes32 constant PARAM__TOKEN = 0xee737c77be2981e91c179485406e6d793521b20aca5e2137b6c497949a74bc94;
/// @custom:keccak lens.param.recipients
bytes32 constant PARAM__RECIPIENTS = 0x7f7e01c87d5278dd08505253491cf5d6b30930036f6afa2ae22a980882f2cac1;
/// @custom:keccak lens.param.isImmutable
bytes32 constant PARAM__IS_IMMUTABLE = 0x4d1cad3e438026974130ac84979964dd6019eace55216c3de16bc79e36a4c44b;

contract SimpleCollectActionTest is Test, BaseDeployments {
    address mockFeed;

    function setUp() public override {
        mockFeed = address(new MockFeed());
        super.setUp();
    }

    function testCanSetupCollectWithNative(uint256 amount, address recipient, bool isImmutable) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(TREASURY_ADDRESS));
        vm.assume(recipient.code.length == 0);
        vm.assume(uint160(recipient) > type(uint16).max); // skip system contracts
        assumeNotForgeAddress(recipient);

        amount = amount % (1 << 95);
        vm.assume(amount > 0);
        vm.deal(address(this), amount);

        KeyValue[] memory params = _toKeyValueArray(
            KeyValue({key: PARAM__AMOUNT, value: abi.encode(amount)}),
            KeyValue({key: PARAM__TOKEN, value: abi.encode(NATIVE_TOKEN)}),
            KeyValue({key: PARAM__RECIPIENTS, value: abi.encode(_toRecipientDataArray(recipient))}),
            KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(isImmutable)})
        );

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);
    }

    function testCanCollectWithNative(uint256 amount, address recipient, address collector, bool isImmutable) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(TREASURY_ADDRESS));
        vm.assume(recipient.code.length == 0);
        vm.assume(uint160(recipient) > type(uint16).max); // skip system contracts
        assumeNotForgeAddress(recipient);

        vm.assume(collector != address(0));
        vm.assume(collector != address(TREASURY_ADDRESS));
        vm.assume(collector.code.length == 0);
        vm.assume(uint160(collector) > type(uint16).max); // skip system contracts
        assumeNotForgeAddress(collector);

        vm.assume(collector != recipient); // We can test this case separately

        amount = amount % (1 << 95);
        vm.assume(amount > 0);
        vm.deal(collector, amount);

        KeyValue[] memory params = _toKeyValueArray(
            KeyValue({key: PARAM__AMOUNT, value: abi.encode(amount)}),
            KeyValue({key: PARAM__TOKEN, value: abi.encode(NATIVE_TOKEN)}),
            KeyValue({key: PARAM__RECIPIENTS, value: abi.encode(_toRecipientDataArray(recipient))}),
            KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(isImmutable)})
        );

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);

        KeyValue[] memory collectParams = _toKeyValueArray(
            KeyValue({key: PARAM__AMOUNT, value: abi.encode(amount)}),
            KeyValue({key: PARAM__TOKEN, value: abi.encode(NATIVE_TOKEN)})
        );

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 treasuryBalanceBefore = address(TREASURY_ADDRESS).balance;

        vm.prank(collector);
        ActionHub(actionHub).executePostAction{value: amount}(
            address(simpleCollectAction), mockFeed, postId, collectParams
        );

        uint256 recipientBalanceAfter = recipient.balance;
        uint256 treasuryBalanceAfter = address(TREASURY_ADDRESS).balance;

        uint256 expectedTreasuryBalanceChange = amount * TREASURY_FEE_BPS / BPS_MAX;
        uint256 expectedRecipientBalanceChange = amount - expectedTreasuryBalanceChange;

        assertEq(
            recipientBalanceAfter, recipientBalanceBefore + expectedRecipientBalanceChange, "Recipient balance mismatch"
        );
        assertEq(
            treasuryBalanceAfter, treasuryBalanceBefore + expectedTreasuryBalanceChange, "Treasury balance mismatch"
        );
    }

    function testCanCollectAfterEdits_Mutable() public {
        KeyValue[] memory params = _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(false)}));

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        MockFeed(mockFeed).setContentURI("1");
        bytes memory result =
            ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);
        CollectActionData memory configurationData = abi.decode(result, (CollectActionData));

        KeyValue[] memory collectParams = _emptyKeyValueArray();

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId1 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("2");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId2 = abi.decode(result, (uint256));

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId3 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("4");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId4 = abi.decode(result, (uint256));

        LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);

        string memory latestContentURI = MockFeed(mockFeed).getPost(postId).contentURI;

        assertEq(latestContentURI, "4");
        assertEq(collection.tokenURI(tokenId1), latestContentURI);
        assertEq(collection.tokenURI(tokenId2), latestContentURI);
        assertEq(collection.tokenURI(tokenId3), latestContentURI);
        assertEq(collection.tokenURI(tokenId4), latestContentURI);

        MockFeed(mockFeed).setContentURI("5");
        latestContentURI = MockFeed(mockFeed).getPost(postId).contentURI;

        assertEq(latestContentURI, "5");
        assertEq(collection.tokenURI(tokenId1), latestContentURI);
        assertEq(collection.tokenURI(tokenId2), latestContentURI);
        assertEq(collection.tokenURI(tokenId3), latestContentURI);
        assertEq(collection.tokenURI(tokenId4), latestContentURI);
    }

    function testCanCollectAfterEdits_Immutable() public {
        KeyValue[] memory params = _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(true)}));

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        MockFeed(mockFeed).setContentURI("1");
        bytes memory result =
            ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);
        CollectActionData memory configurationData = abi.decode(result, (CollectActionData));

        KeyValue[] memory collectParams = _emptyKeyValueArray();

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId1 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("2");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId2 = abi.decode(result, (uint256));

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId3 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("4");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId4 = abi.decode(result, (uint256));

        LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);

        assertEq(collection.tokenURI(tokenId1), "1");
        assertEq(collection.tokenURI(tokenId2), "2");
        assertEq(collection.tokenURI(tokenId3), "2");
        assertEq(collection.tokenURI(tokenId4), "4");
    }

    function testCanCollectAfterEdits_EditBeforeFirstCollect_Mutable() public {
        KeyValue[] memory params = _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(false)}));

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        MockFeed(mockFeed).setContentURI("0");
        bytes memory result =
            ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);
        CollectActionData memory configurationData = abi.decode(result, (CollectActionData));

        MockFeed(mockFeed).setContentURI("1");

        KeyValue[] memory collectParams = _emptyKeyValueArray();

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId1 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("2");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId2 = abi.decode(result, (uint256));

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId3 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("4");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId4 = abi.decode(result, (uint256));

        LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);

        string memory latestContentURI = MockFeed(mockFeed).getPost(postId).contentURI;

        assertEq(latestContentURI, "4");
        assertEq(collection.tokenURI(tokenId1), latestContentURI);
        assertEq(collection.tokenURI(tokenId2), latestContentURI);
        assertEq(collection.tokenURI(tokenId3), latestContentURI);
        assertEq(collection.tokenURI(tokenId4), latestContentURI);

        MockFeed(mockFeed).setContentURI("5");
        latestContentURI = MockFeed(mockFeed).getPost(postId).contentURI;

        assertEq(latestContentURI, "5");
        assertEq(collection.tokenURI(tokenId1), latestContentURI);
        assertEq(collection.tokenURI(tokenId2), latestContentURI);
        assertEq(collection.tokenURI(tokenId3), latestContentURI);
        assertEq(collection.tokenURI(tokenId4), latestContentURI);
    }

    function testCanCollectAfterEdits_EditBeforeFirstCollect_Immutable() public {
        KeyValue[] memory params = _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(true)}));

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));

        MockFeed(mockFeed).setContentURI("0");
        bytes memory result =
            ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, params);
        CollectActionData memory configurationData = abi.decode(result, (CollectActionData));

        MockFeed(mockFeed).setContentURI("1");

        KeyValue[] memory collectParams = _emptyKeyValueArray();

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId1 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("2");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId2 = abi.decode(result, (uint256));

        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId3 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("4");
        result = ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId4 = abi.decode(result, (uint256));

        LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);

        assertEq(collection.tokenURI(tokenId1), "1");
        assertEq(collection.tokenURI(tokenId2), "2");
        assertEq(collection.tokenURI(tokenId3), "2");
        assertEq(collection.tokenURI(tokenId4), "4");
    }

    // *** Test deprecated as the decision to not preserve WYSIWYG for legacy collections was made.
    // ************************************************************************************************
    // function testCannotCollectAfterEdits_PreviousCollectionVersion() public {
    //     KeyValue[] memory params = _emptyKeyValueArray();

    //     uint256 postId = 1;
    //     MockFeed(mockFeed).setPostAuthor(postId, address(this));
    //     MockFeed(mockFeed).setContentURI("1");

    //     MockSimpleCollectAction mockSimpleCollectAction = new MockSimpleCollectAction(actionHub);

    //     vm.prank(address(mockSimpleCollectAction));
    //     MockLegacyLensCollectedPost legacyCollection = new MockLegacyLensCollectedPost(mockFeed, postId, true);

    //     bytes memory result =
    //         ActionHub(actionHub).configurePostAction(address(mockSimpleCollectAction), mockFeed, postId, params);

    //     mockSimpleCollectAction.setCollectionAddress(mockFeed, postId, address(legacyCollection));
    //     CollectActionData memory configurationData = abi.decode(result, (CollectActionData));
    //     configurationData.collectionAddress = address(legacyCollection);

    //     KeyValue[] memory collectParams = _emptyKeyValueArray();

    //     result =
    //         ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);
    //     uint256 tokenId1 = abi.decode(result, (uint256));

    //     MockFeed(mockFeed).setContentURI("2");

    //     vm.expectRevert(Errors.InvalidParameter.selector);
    //     ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);

    //     MockFeed(mockFeed).setContentURI("1");

    //     result =
    //         ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);
    //     uint256 tokenId2 = abi.decode(result, (uint256));

    //     LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);
    //     assertEq(collection.tokenURI(tokenId1), "1");
    //     assertEq(collection.tokenURI(tokenId2), "1");
    // }

    function testCollectAfterEdits_PreviousCollectionVersion(bool isImmutable) public {
        KeyValue[] memory params = _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(isImmutable)}));

        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));
        MockFeed(mockFeed).setContentURI("1");

        MockSimpleCollectAction mockSimpleCollectAction = new MockSimpleCollectAction(actionHub);

        vm.prank(address(mockSimpleCollectAction));
        MockLegacyLensCollectedPost legacyCollection = new MockLegacyLensCollectedPost(mockFeed, postId, true);

        bytes memory result =
            ActionHub(actionHub).configurePostAction(address(mockSimpleCollectAction), mockFeed, postId, params);

        mockSimpleCollectAction.setCollectionAddress(mockFeed, postId, address(legacyCollection));
        CollectActionData memory configurationData = abi.decode(result, (CollectActionData));
        configurationData.collectionAddress = address(legacyCollection);

        KeyValue[] memory collectParams = _emptyKeyValueArray();

        result =
            ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId1 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("2");

        result =
            ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId2 = abi.decode(result, (uint256));

        MockFeed(mockFeed).setContentURI("1");

        result =
            ActionHub(actionHub).executePostAction(address(mockSimpleCollectAction), mockFeed, postId, collectParams);
        uint256 tokenId3 = abi.decode(result, (uint256));

        LensCollectedPost collection = LensCollectedPost(configurationData.collectionAddress);
        assertEq(collection.tokenURI(tokenId1), "1");
        assertEq(collection.tokenURI(tokenId2), "1");
        assertEq(collection.tokenURI(tokenId3), "1");
    }

    function test_Collect(bool isImmutable) public {
        uint256 postId = 1;
        MockFeed(mockFeed).setPostAuthor(postId, address(this));
        MockFeed(mockFeed).setContentURI("1");

        // Configure
        KeyValue[] memory configParams =
            _toKeyValueArray(KeyValue({key: PARAM__IS_IMMUTABLE, value: abi.encode(isImmutable)}));
        ActionHub(actionHub).configurePostAction(address(simpleCollectAction), mockFeed, postId, configParams);

        // Collect
        KeyValue[] memory execParams = _emptyKeyValueArray();
        ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, execParams);

        // Collect again
        ActionHub(actionHub).executePostAction(address(simpleCollectAction), mockFeed, postId, execParams);
    }
}
