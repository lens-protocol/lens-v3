// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IPostRule} from "contracts/core/interfaces/IPostRule.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract FollowersOnlyPostRule is OwnableMetadataBasedRule, Initializable, IPostRule {
    /// @custom:keccak lens.param.graph
    bytes32 constant PARAM__GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;
    /// @custom:keccak lens.param.repliesRestricted
    bytes32 constant PARAM__REPLIES_RESTRICTED = 0x4ce0155a596c1a9d5bcefb32cdbf357c849ac621a9b91d222b367cf53fe79a6f;
    /// @custom:keccak lens.param.repostsRestricted
    bytes32 constant PARAM__REPOSTS_RESTRICTED = 0x4888fd5474d5999daba89bdcba85aa57b7a2ed60bdcccee0a949f2da51050bbd;
    /// @custom:keccak lens.param.quotesRestricted
    bytes32 constant PARAM__QUOTES_RESTRICTED = 0x323cbd3bdd5537df3af23e8d4c6c6bb31c9fa33346759abf247f998a32cda0a2;

    /// @custom:keccak lens.storage.FollowersOnlyPostRule
    bytes32 constant STORAGE__FOLLOWERS_ONLY_POST_RULE =
        0x72122f9a33a0e5d62090bb94e554ef20898123fa69fd6696be30406d0bbc2d36;

    struct Configuration {
        address graph;
        bool repliesRestricted;
        bool repostsRestricted;
        bool quotesRestricted;
    }

    struct Storage {
        mapping(address feed => mapping(bytes32 configSalt => mapping(uint256 postId => Configuration config)))
            configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__FOLLOWERS_ONLY_POST_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, uint256 postId, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__GRAPH) {
                configuration.graph = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__REPLIES_RESTRICTED) {
                configuration.repliesRestricted = abi.decode(ruleParams[i].value, (bool));
            } else if (ruleParams[i].key == PARAM__REPOSTS_RESTRICTED) {
                configuration.repostsRestricted = abi.decode(ruleParams[i].value, (bool));
            } else if (ruleParams[i].key == PARAM__QUOTES_RESTRICTED) {
                configuration.quotesRestricted = abi.decode(ruleParams[i].value, (bool));
            }
        }
        IGraph(configuration.graph).isFollowing(address(this), msg.sender); // Verifies the provided address is a graph
        require(
            configuration.repliesRestricted || configuration.repostsRestricted || configuration.quotesRestricted,
            Errors.InvalidParameter()
        );
        $storage().configuration[msg.sender][configSalt][postId] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt][rootPostId];
        if (_shouldRestrictionBeApplied(configuration, rootPostId, postParams)) {
            IFeed feed = IFeed(msg.sender);
            IGraph graph = IGraph(configuration.graph);
            address rootPostAuthor = feed.getPostAuthor(rootPostId);
            address newPostAuthor = feed.getPostAuthor(postId);
            require(
                graph.isFollowing({followerAccount: newPostAuthor, targetAccount: rootPostAuthor}), Errors.NotFollowing()
            );
        }
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _shouldRestrictionBeApplied(
        Configuration memory configuration,
        uint256 rootPostId,
        CreatePostParams calldata postParams
    ) internal view returns (bool) {
        IFeed feed = IFeed(msg.sender);
        if (feed.getPostAuthor(rootPostId) == postParams.author) {
            // Author can always reply, repost or quote their own posts.
            return false;
        }
        if (configuration.repliesRestricted && postParams.repliedPostId != 0) {
            uint256 repliedPostRootId = feed.getPost(postParams.repliedPostId).rootPostId;
            if (repliedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.repostsRestricted && postParams.repostedPostId != 0) {
            uint256 repostedPostRootId = feed.getPost(postParams.repostedPostId).rootPostId;
            if (repostedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.quotesRestricted && postParams.quotedPostId != 0) {
            uint256 quotedPostRootId = feed.getPost(postParams.quotedPostId).rootPostId;
            if (quotedPostRootId == rootPostId) {
                return true;
            }
        }
        return false;
    }
}
