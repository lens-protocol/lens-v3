// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IFeed, Post, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {PostCreationParams} from "contracts/migration/primitives/MigrationFeed.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {CreateAccountParams, CreateUsernameParams} from "@extensions/factories/LensFactory.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";

struct PostData {
    address author;
    string contentURI;
    uint256 repostedPostId;
    uint256 quotedPostId;
    uint256 repliedPostId;
    uint256 authorPostSequentialId;
    uint80 creationTimestamp;
    address source;
}

struct FollowData {
    address followerAccount;
    address accountToFollow;
    uint256 followId;
    uint256 timestamp;
}

contract MigrationFlowTest is BaseDeployments {
    IFeed migrationFeed;

    address deployer = makeAddr("DEPLOYER");
    address migrator = makeAddr("MIGRATOR");

    address account;
    address accountWithoutUsername;

    address accountOwner = makeAddr("ACCOUNT_OWNER");
    address accountWithoutUsernameOwner = makeAddr("ACCOUNT_WITHOUT_USERNAME_OWNER");

    address followSource1 = makeAddr("FOLLOW_SOURCE_1");
    address followSource2 = makeAddr("FOLLOW_SOURCE_2");
    address followTarget1 = makeAddr("FOLLOW_TARGET_1");
    address followTarget2 = makeAddr("FOLLOW_TARGET_2");

    address usernameOwner = makeAddr("USERNAME_OWNER");

    address newOwner = makeAddr("NEW_OWNER");

    IFeed lensDefaultFeed;
    IGraph lensDefaultGraph;
    INamespace lensDefaultNamespace;

    address oneApp;
    address otherApp;

    uint256 postId;
    uint256 replyId;
    uint256 quoteId;
    uint256 repostId;

    PostData postData = PostData({
        author: makeAddr("POST_AUTHOR"),
        contentURI: "uri://post_content",
        repostedPostId: 0,
        quotedPostId: 0,
        repliedPostId: 0,
        authorPostSequentialId: 5,
        creationTimestamp: 12345,
        source: makeAddr("POST_SOURCE")
    });

    PostData replyData = PostData({
        author: makeAddr("REPLY_AUTHOR"),
        contentURI: "uri://reply_content",
        repostedPostId: 0,
        quotedPostId: 0,
        repliedPostId: 0,
        authorPostSequentialId: 3,
        creationTimestamp: 23456,
        source: makeAddr("REPLY_SOURCE")
    });

    PostData quoteData = PostData({
        author: makeAddr("QUOTE_AUTHOR"),
        contentURI: "uri://quote_content",
        repostedPostId: 0,
        quotedPostId: 0,
        repliedPostId: 0,
        authorPostSequentialId: 2,
        creationTimestamp: 34567,
        source: makeAddr("QUOTE_SOURCE")
    });

    PostData repostData = PostData({
        author: makeAddr("REPOST_AUTHOR"),
        contentURI: "",
        repostedPostId: 0,
        quotedPostId: 0,
        repliedPostId: 0,
        authorPostSequentialId: 1,
        creationTimestamp: 45678,
        source: makeAddr("REPOST_SOURCE")
    });

    FollowData followData1 =
        FollowData({followerAccount: followSource1, accountToFollow: followTarget1, followId: 31, timestamp: 912345});

    FollowData followData2 =
        FollowData({followerAccount: followSource2, accountToFollow: followTarget2, followId: 22, timestamp: 923456});

    function setUp() public override(BaseDeployments) {
        BaseDeployments.switchMigrationMode(true);
        BaseDeployments.setUp();

        lensDefaultFeed = IFeed(
            lensFactory.deployFeed({
                metadataURI: "uri://feed",
                owner: primitivesOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        lensDefaultGraph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "uri://graph",
                owner: primitivesOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        lensDefaultNamespace = INamespace(
            lensFactory.deployNamespace({
                namespace: "lens.global",
                metadataURI: "uri://namespace",
                owner: primitivesOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray(),
                nftName: "Lens Global",
                nftSymbol: "LENS"
            })
        );
    }

    function testMigrationFlow() public {
        _migrateAccounts();
        _migratePosts();
        _migrateFollows();
        _migrateUsernames();

        _transferOwnership();
    }

    function _migrateAccounts() internal {
        account = lensFactory.createAccountWithUsernameFree(
            address(lensDefaultNamespace),
            CreateAccountParams({
                metadataURI: "uri://account",
                owner: accountOwner,
                accountManagers: _emptyAddressArray(),
                accountManagersPermissions: _emptyAccountManagerPermissionsArray(),
                accountCreationSourceStamp: _emptySourceStamp(),
                accountExtraData: _emptyKeyValueArray()
            }),
            CreateUsernameParams({
                username: "migration_username1",
                createUsernameCustomParams: _emptyKeyValueArray(),
                createUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
                assignUsernameCustomParams: _emptyKeyValueArray(),
                unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
                assignRuleProcessingParams: _emptyRuleProcessingParamsArray(),
                usernameExtraData: _emptyKeyValueArray()
            })
        );

        accountWithoutUsername = lensFactory.deployAccount({
            metadataURI: "uri://accountWithoutUsername",
            owner: accountWithoutUsernameOwner,
            accountManagers: _emptyAddressArray(),
            accountManagersPermissions: _emptyAccountManagerPermissionsArray(),
            sourceStamp: _emptySourceStamp(),
            extraData: _emptyKeyValueArray()
        });
    }

    function _migratePosts() internal {
        vm.startPrank(migrator);
        postId = lensDefaultFeed.createPost({
            postParams: CreatePostParams({
                author: postData.author,
                contentURI: postData.contentURI,
                repostedPostId: postData.repostedPostId,
                quotedPostId: postData.quotedPostId,
                repliedPostId: postData.repliedPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _toKeyValueArray(
                KeyValue({
                    key: bytes32(0),
                    value: abi.encode(
                        PostCreationParams({
                            authorPostSequentialId: postData.authorPostSequentialId,
                            creationTimestamp: postData.creationTimestamp,
                            source: postData.source
                        })
                    )
                })
            ),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        replyData.repliedPostId = postId;
        replyId = lensDefaultFeed.createPost({
            postParams: CreatePostParams({
                author: replyData.author,
                contentURI: replyData.contentURI,
                repostedPostId: replyData.repostedPostId,
                quotedPostId: replyData.quotedPostId,
                repliedPostId: replyData.repliedPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _toKeyValueArray(
                KeyValue({
                    key: bytes32(0),
                    value: abi.encode(
                        PostCreationParams({
                            authorPostSequentialId: replyData.authorPostSequentialId,
                            creationTimestamp: replyData.creationTimestamp,
                            source: replyData.source
                        })
                    )
                })
            ),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        quoteData.quotedPostId = postId;
        quoteId = lensDefaultFeed.createPost({
            postParams: CreatePostParams({
                author: quoteData.author,
                contentURI: quoteData.contentURI,
                repostedPostId: quoteData.repostedPostId,
                quotedPostId: quoteData.quotedPostId,
                repliedPostId: quoteData.repliedPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _toKeyValueArray(
                KeyValue({
                    key: bytes32(0),
                    value: abi.encode(
                        PostCreationParams({
                            authorPostSequentialId: quoteData.authorPostSequentialId,
                            creationTimestamp: quoteData.creationTimestamp,
                            source: quoteData.source
                        })
                    )
                })
            ),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        repostData.repostedPostId = postId;
        repostId = lensDefaultFeed.createPost({
            postParams: CreatePostParams({
                author: repostData.author,
                contentURI: repostData.contentURI,
                repostedPostId: repostData.repostedPostId,
                quotedPostId: repostData.quotedPostId,
                repliedPostId: repostData.repliedPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _toKeyValueArray(
                KeyValue({
                    key: bytes32(0),
                    value: abi.encode(
                        PostCreationParams({
                            authorPostSequentialId: repostData.authorPostSequentialId,
                            creationTimestamp: repostData.creationTimestamp,
                            source: repostData.source
                        })
                    )
                })
            ),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
        vm.stopPrank();
    }

    function _migrateFollows() internal {
        vm.startPrank(migrator);
        lensDefaultGraph.follow({
            followerAccount: followData1.followerAccount,
            accountToFollow: followData1.accountToFollow,
            customParams: _toKeyValueArray(
                KeyValue({key: bytes32(0), value: abi.encode(followData1.followId, followData1.timestamp)})
            ),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        lensDefaultGraph.follow({
            followerAccount: followData2.followerAccount,
            accountToFollow: followData2.accountToFollow,
            customParams: _toKeyValueArray(
                KeyValue({key: bytes32(0), value: abi.encode(followData2.followId, followData2.timestamp)})
            ),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
        vm.stopPrank();
    }

    function _migrateUsernames() internal {
        vm.startPrank(migrator);
        lensDefaultNamespace.createUsername({
            account: usernameOwner,
            username: "migration_username2",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
        vm.stopPrank();
    }

    function _transferOwnership() internal {}
}
