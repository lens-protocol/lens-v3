// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {App, InitialProperties} from "contracts/primitives/app/App.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";

contract AppTest is Test {
    App public app;
    address owner = makeAddr("OWNER");
    address graph = makeAddr("GRAPH");
    address[] feeds = [makeAddr("FEED1"), makeAddr("FEED2")];
    address username = makeAddr("USERNAME");
    address[] communities = [makeAddr("COMMUNITY1"), makeAddr("COMMUNITY2")];
    address defaultFeed = feeds[0];
    address defaultCommunity = communities[0];
    address[] signers = [makeAddr("SIGNER1"), makeAddr("SIGNER2")];
    address paymaster = makeAddr("PAYMASTER");

    event Lens_App_GraphAdded(address graph);
    event Lens_App_DefaultGraphSet(address graph);
    event Lens_App_FeedAdded(address feed);
    event Lens_App_FeedRemoved(address feed);
    event Lens_App_FeedsSet(address[] feeds);
    event Lens_App_DefaultFeedSet(address feed);
    event Lens_App_UsernameAdded(address username);
    event Lens_App_DefaultUsernameSet(address username);
    event Lens_App_CommunityAdded(address community);
    event Lens_App_CommunityRemoved(address community);
    event Lens_App_CommunitiesSet(address[] communities);
    event Lens_App_DefaultCommunitySet(address community);
    event Lens_App_PaymasterAdded(address paymaster);
    event Lens_App_DefaultPaymasterSet(address paymaster);
    event Lens_App_MetadataUriSet(string metadataURI);

    function setUp() public {
        InitialProperties memory props = InitialProperties({
            _graph: graph,
            _feeds: feeds,
            _username: username,
            _communities: communities,
            _defaultFeed: defaultFeed,
            _defaultCommunity: defaultCommunity,
            _signers: signers,
            _paymaster: paymaster
        });

        app = new App(IAccessControl(owner), "Test Metadata URI", owner, props);
    }

    function testSetGraph() public {
        address newGraph = makeAddr("NEW_GRAPH");

        // Expect the events to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_GraphAdded(newGraph);

        vm.expectEmit(true, true, true, true);
        emit Lens_App_DefaultGraphSet(newGraph);

        vm.prank(owner);
        app.setGraph(newGraph);

        assertEq(app.getDefaultGraph(), newGraph, "Graph should be updated");
        assertEq(app.getGraphs()[0], newGraph, "Graphs array should be updated");
    }

    function testSetFeeds() public {
        address[] memory newFeeds = new address[](2);
        newFeeds[0] = makeAddr("NEW_FEED1");
        newFeeds[1] = makeAddr("NEW_FEED2");

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_FeedsSet(newFeeds);

        vm.prank(owner);
        app.setFeeds(newFeeds);

        assertEq(app.getFeeds()[0], newFeeds[0], "Feed1 should be updated");
        assertEq(app.getFeeds()[1], newFeeds[1], "Feed2 should be updated");
        assertEq(app.getDefaultFeed(), newFeeds[0], "Default feed should be updated");
    }

    function testAddFeed() public {
        address newFeed = makeAddr("NEW_FEED");

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_FeedAdded(newFeed);

        vm.prank(owner);
        app.addFeed(newFeed);

        assertEq(app.getFeeds()[2], newFeed, "New feed should be added");
    }

    function testRemoveFeed() public {
        address feedToRemove = feeds[0];

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_FeedRemoved(feedToRemove);

        vm.prank(owner);
        app.removeFeed(feedToRemove, 0);

        assertEq(app.getFeeds()[0], address(0), "Feed should be removed");
    }

    function testSetUsername() public {
        address newUsername = makeAddr("NEW_USERNAME");

        // Expect the events to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_UsernameAdded(newUsername);

        vm.expectEmit(true, true, true, true);
        emit Lens_App_DefaultUsernameSet(newUsername);

        vm.prank(owner);
        app.setUsername(newUsername);

        assertEq(app.getDefaultUsername(), newUsername, "Username should be updated");
        assertEq(app.getUsernames()[0], newUsername, "Usernames array should be updated");
    }

    function testSetCommunity() public {
        address[] memory newCommunities = new address[](2);
        newCommunities[0] = makeAddr("NEW_COMMUNITY1");
        newCommunities[1] = makeAddr("NEW_COMMUNITY1");
        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_CommunitiesSet(newCommunities);

        vm.prank(owner);
        app.setCommunity(newCommunities);

        assertEq(app.getCommunities()[0], newCommunities[0], "Community1 should be updated");
        assertEq(app.getCommunities()[1], newCommunities[1], "Community2 should be updated");
        assertEq(app.getDefaultCommunity(), newCommunities[0], "Default community should be updated");
    }

    function testAddCommunity() public {
        address newCommunity = makeAddr("NEW_COMMUNITY");

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_CommunityAdded(newCommunity);

        vm.prank(owner);
        app.addCommunity(newCommunity);

        // Get the updated array of communities
        address[] memory communities = app.getCommunities();

        // Assert that the new community is added at the last index
        assertEq(communities[communities.length - 1], newCommunity, "New community should be added at the end of the array");
    }


    function testRemoveCommunity() public {
        address communityToRemove = communities[0];

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_CommunityRemoved(communityToRemove);

        vm.prank(owner);
        app.removeCommunity(communityToRemove, 0);

        assertEq(app.getCommunities()[0], address(0), "Community should be removed");
    }

    function testSetPaymaster() public {
        address newPaymaster = makeAddr("NEW_PAYMASTER");

        // Expect the events to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_App_PaymasterAdded(newPaymaster);

        vm.expectEmit(true, true, true, true);
        emit Lens_App_DefaultPaymasterSet(newPaymaster);

        vm.prank(owner);
        app.setPaymaster(newPaymaster);

        //assertEq(app.getDefaultPaymaster(), newPaymaster, "Paymaster should be updated");
    }
}
