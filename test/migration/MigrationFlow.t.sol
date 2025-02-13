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
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {App} from "contracts/extensions/primitives/app/App.sol";
import {Account as AccountContract} from "contracts/extensions/account/Account.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";
import {Graph} from "contracts/core/primitives/graph/Graph.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";
import {LensFactory} from "contracts/extensions/factories/LensFactory.sol";
import {Log4EventData, EventEmitter} from "contracts/migration/EventEmitter.sol";

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
        _setAccessControls();
        _upgradeBeacons();
        _upgradeFactories();
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

        Log4EventData[] memory logs4 = new Log4EventData[](1);
        logs4[0] = Log4EventData({
            topic1: bytes32(0x72A01E0C4465EAB653BB461BFFF7CAA13615C0CC7BEC21448F78D06F78430887),
            topic2: bytes32(0x000000000000000000000000ED68F7E632BC033D9697FC26965077E5D9D0120C),
            topic3: bytes32(0x0000000000000000000000001FA75D26819AC733BF7B1C1B36C3F8AEF32D2CC0),
            topic4: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            data: hex"000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000E0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001C0000000000000000000000000000000000000000000000000000000000000003D68747470733A2F2F6D657461646174612E6865792E78797A2F62353833616562312D356661612D346232632D393635612D333462343335323832313337000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000046DBAC25CFA81DFFAD10CE667C339755DBCD3D7F000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000C00871A425F7AF88EDC1038EB21824A0BF159D8A374EB15240E21A829EC3133463000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000043078303100000000000000000000000000000000000000000000000000000000119C636440496D74AC9C094907AE935F079BE74A4190CBA94EE21CFFBE017DE0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000080000000062822F10000000000000000000000000000000000000000000000000"
        });

        EventEmitter(accountWithoutUsername).emitEventsLog4(logs4);
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

    function _transferOwnership() internal {
        vm.startPrank(factoriesProxyOwner);
        ITransparentUpgradeableProxy(address(accessControlFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(accountFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(appFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(feedFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(graphFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(groupFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(namespaceFactory)).changeAdmin(newOwner);
        ITransparentUpgradeableProxy(address(lensFactory)).changeAdmin(newOwner);
        vm.stopPrank();

        vm.startPrank(beaconOwner);
        Beacon(appBeacon).transferOwnership(newOwner);
        Beacon(accountBeacon).transferOwnership(newOwner);
        Beacon(feedBeacon).transferOwnership(newOwner);
        Beacon(graphBeacon).transferOwnership(newOwner);
        Beacon(groupBeacon).transferOwnership(newOwner);
        Beacon(namespaceBeacon).transferOwnership(newOwner);
        vm.stopPrank();

        vm.startPrank(primitivesOwner);
        ProxyAdmin feedProxyAdmin = ProxyAdmin(BeaconProxy(payable(address(lensDefaultFeed))).proxy__getProxyAdmin());
        feedProxyAdmin.transferOwnership(newOwner);

        ProxyAdmin graphProxyAdmin = ProxyAdmin(BeaconProxy(payable(address(lensDefaultGraph))).proxy__getProxyAdmin());
        graphProxyAdmin.transferOwnership(newOwner);

        ProxyAdmin namespaceProxyAdmin =
            ProxyAdmin(BeaconProxy(payable(address(lensDefaultNamespace))).proxy__getProxyAdmin());
        namespaceProxyAdmin.transferOwnership(newOwner);

        // TODO: Also do on Apps if not done initially? Depends who Josh sets as owner of the App
        vm.stopPrank();
    }

    function _setAccessControls() internal {
        IAccessControl feedAccessControl = IAccessControl(
            address(accessControlFactory.deployOwnerAdminOnlyAccessControl(newOwner, _emptyAddressArray()))
        );
        AccessControlled(address(lensDefaultFeed)).setAccessControl(feedAccessControl);

        IAccessControl graphAccessControl = IAccessControl(
            address(accessControlFactory.deployOwnerAdminOnlyAccessControl(newOwner, _emptyAddressArray()))
        );
        AccessControlled(address(lensDefaultGraph)).setAccessControl(graphAccessControl);

        IAccessControl namespaceAccessControl = IAccessControl(
            address(accessControlFactory.deployOwnerAdminOnlyAccessControl(newOwner, _emptyAddressArray()))
        );
        AccessControlled(address(lensDefaultNamespace)).setAccessControl(namespaceAccessControl);

        // TODO: Also do on Apps.
    }

    function _upgradeBeacons() internal {
        appImpl = address(new App());
        accountImpl = address(new AccountContract());
        feedImpl = address(new Feed());
        graphImpl = address(new Graph());
        namespaceImpl = address(new Namespace());

        vm.startPrank(newOwner);
        Beacon(appBeacon).setImplementationForVersion(1, address(appImpl));
        Beacon(accountBeacon).setImplementationForVersion(1, address(accountImpl));
        Beacon(feedBeacon).setImplementationForVersion(1, address(feedImpl));
        Beacon(graphBeacon).setImplementationForVersion(1, address(graphImpl));
        Beacon(namespaceBeacon).setImplementationForVersion(1, address(namespaceImpl));
        vm.stopPrank();
    }

    function _upgradeFactories() internal {
        address accessControlFactoryImpl = address(new AccessControlFactory(accessControlLock));
        address accountFactoryImpl = address(new AccountFactory(accountBeacon, proxyAdminLock));
        address appFactoryImpl = address(new AppFactory(appBeacon, proxyAdminLock));
        address feedFactoryImpl = address(new FeedFactory(feedBeacon, proxyAdminLock));
        address graphFactoryImpl = address(new GraphFactory(graphBeacon, proxyAdminLock));
        address namespaceFactoryImpl = address(new NamespaceFactory(namespaceBeacon, proxyAdminLock));

        vm.startPrank(newOwner);
        ITransparentUpgradeableProxy(address(accessControlFactory)).upgradeTo(accessControlFactoryImpl);
        ITransparentUpgradeableProxy(address(accountFactory)).upgradeTo(accountFactoryImpl);
        ITransparentUpgradeableProxy(address(appFactory)).upgradeTo(appFactoryImpl);
        ITransparentUpgradeableProxy(address(feedFactory)).upgradeTo(feedFactoryImpl);
        ITransparentUpgradeableProxy(address(graphFactory)).upgradeTo(graphFactoryImpl);
        ITransparentUpgradeableProxy(address(namespaceFactory)).upgradeTo(namespaceFactoryImpl);
        vm.stopPrank();

        (
            address lensAccessControlFactory,
            address lensAccountFactory,
            address lensAppFactory,
            address lensFeedFactory,
            address lensGraphFactory,
            address lensGroupFactory,
            address lensNamespaceFactory
        ) = lensFactory.getFactories();

        (
            address lensAccountBlockingRule,
            address lensGroupGatedFeedRule,
            address lensUsernameSimpleCharsetRule,
            address lensBanMemberGroupRule
        ) = lensFactory.getRules();

        address lensFactoryImpl = address(
            new LensFactory(
                AccessControlFactory(lensAccessControlFactory),
                AccountFactory(lensAccountFactory),
                AppFactory(lensAppFactory),
                GroupFactory(lensGroupFactory),
                FeedFactory(lensFeedFactory),
                GraphFactory(lensGraphFactory),
                NamespaceFactory(lensNamespaceFactory),
                lensAccountBlockingRule,
                lensGroupGatedFeedRule,
                lensUsernameSimpleCharsetRule,
                lensBanMemberGroupRule
            )
        );

        vm.prank(newOwner);
        ITransparentUpgradeableProxy(address(lensFactory)).upgradeTo(lensFactoryImpl);
    }
}
