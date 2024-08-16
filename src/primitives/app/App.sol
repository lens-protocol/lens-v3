// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from 'src/primitives/access-control/IAccessControl.sol';

interface IApp {
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
}

contract App is IApp {
    IAccessControl _accessControl; // Owner, admins, moderators, permissions.
    string _metadataURI; // Name, description, logo, other attribiutes like category/topic, etc.
    address _treasury; // Can also be defined as a permission in the AC... and allow multiple revenue recipients!

    address[] _graphs; // Graphs that this App uses.
    address[] _feeds; // Feeds that this App uses
    address[] _usernames; // Usernames that this App uses.
    address[] _communities; // Communities that this App uses.

    address _defaultGraph;
    address _defaultFeed;
    address _defaultUsername;
    address _defaultCommunity;

    address[] _signers; // Signers that belong to this App.

    // TODO: Add ACCESS CONTROL to all the functions below!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    // TODO:
    // In this implementation we assume you can only have one graph.

    function setGraph(address graph) public {
        // TODO: Check for graph == 0x0, or add a add/remove function.
        if (_graphs.length == 0) {
            _graphs.push(graph);
            _defaultGraph = graph;
        } else {
            _graphs[0] = graph;
            _defaultGraph = graph;
        }
        emit Lens_App_GraphAdded(graph);
        emit Lens_App_DefaultGraphSet(graph);
    }

    // function setDefaultGraph(address graph) public {
    //     _defaultGraph = graph;
    // }

    function setFeeds(address[] memory feeds) public {
        _feeds = feeds;
        if (_feeds.length == 0) {
            delete _defaultFeed;
        } else {
            _defaultFeed = _feeds[0];
        }
        emit Lens_App_FeedsSet(feeds);
    }

    function setDefaultFeed(address feed) public {
        _defaultFeed = feed;
        emit Lens_App_DefaultFeedSet(feed);
    }

    function addFeed(address feed) public {
        // TODO: Add check for duplicate, or use a mapping.
        _feeds.push(feed);
        emit Lens_App_FeedAdded(feed);
    }

    function removeFeed(address feed, uint256 index) public {
        if (_feeds[index] == feed) {
            delete _feeds[index];
        }
        emit Lens_App_FeedRemoved(feed);
    }

    function setUsername(address username) public {
        if (_usernames.length == 0) {
            _usernames.push(username);
            _defaultUsername = username;
        } else {
            _usernames[0] = username;
            _defaultUsername = username;
        }
        emit Lens_App_UsernameAdded(username);
        emit Lens_App_DefaultUsernameSet(username);
    }

    // function setDefaultUsername(address username) public {
    //     _defaultUsername = username;
    // }

    function setCommunity(address[] memory communities) public {
        _communities = communities;
        if (_communities.length == 0) {
            delete _defaultCommunity;
        } else {
            _defaultCommunity = _communities[0];
        }
        emit Lens_App_CommunitiesSet(communities);
    }

    function setDefaultCommunity(address community) public {
        _defaultCommunity = community;
        emit Lens_App_DefaultCommunitySet(community);
    }

    function addCommunity(address community) public {
        // TODO: Add check for duplicate, or use a mapping.
        _communities.push(community);
        emit Lens_App_CommunityAdded(community);
    }

    function removeCommunity(address community, uint256 index) public {
        if (_communities[index] == community) {
            delete _communities[index];
        }
        emit Lens_App_CommunityRemoved(community);
    }

    //////////////////////////////////////////////////////////////////////////
    // Getters
    //////////////////////////////////////////////////////////////////////////

    function getGraphs() public view returns (address[] memory) {
        return _graphs;
    }

    function getFeeds() public view returns (address[] memory) {
        return _feeds;
    }

    function getUsernames() public view returns (address[] memory) {
        return _usernames;
    }

    function getCommunities() public view returns (address[] memory) {
        return _communities;
    }

    function getDefaultGraph() public view returns (address) {
        return _defaultGraph;
    }

    function getDefaultFeed() public view returns (address) {
        return _defaultFeed;
    }

    function getDefaultUsername() public view returns (address) {
        return _defaultUsername;
    }

    function getDefaultCommunity() public view returns (address) {
        return _defaultCommunity;
    }
}