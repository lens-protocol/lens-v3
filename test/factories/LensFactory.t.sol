pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {LensFactory} from "../../contracts/dashboard/factories/LensFactory.sol";
import {AccountFactory} from "../../contracts/dashboard/factories/AccountFactory.sol";
import {AppFactory} from "../../contracts/dashboard/factories/AppFactory.sol";
import {GroupFactory} from "../../contracts/dashboard/factories/GroupFactory.sol";
import {FeedFactory} from "../../contracts/dashboard/factories/FeedFactory.sol";
import {GraphFactory} from "../../contracts/dashboard/factories/GraphFactory.sol";
import {UsernameFactory} from "../../contracts/dashboard/factories/UsernameFactory.sol";
import {Username} from "../../contracts/core/primitives/username/Username.sol";
import {RuleChange, DataElement, SourceStamp, RuleExecutionData} from "../../contracts/core/types/Types.sol";
import {AccountManagerPermissions} from "../../contracts/dashboard/account/Account.sol";
import {AccessControlFactory} from "../../contracts/dashboard/factories/AccessControlFactory.sol";
import {UserBlockingRule} from "../../contracts/rules/base/UserBlockingRule.sol";
import {IGraph} from "../../contracts/core/interfaces/IGraph.sol";
import "../helpers/TypeHelpers.sol";

contract LensFactoryTest is Test {
    LensFactory lensFactory;
    Username username;

    function setUp() public {
        UserBlockingRule userBlockingRule = new UserBlockingRule();

        lensFactory = new LensFactory({
            accessControlFactory: new AccessControlFactory(),
            accountFactory: new AccountFactory(),
            appFactory: new AppFactory(),
            groupFactory: new GroupFactory(),
            feedFactory: new FeedFactory(),
            graphFactory: new GraphFactory(),
            usernameFactory: new UsernameFactory(),
            userBlockingRule: address(userBlockingRule)
        });

        username = Username(
            lensFactory.deployUsername({
                namespace: "bitcoin",
                metadataURI: "satoshi://nakamoto",
                owner: address(this),
                admins: new address[](0),
                rules: new RuleChange[](0),
                extraData: new DataElement[](0),
                nftName: "Bitcoin",
                nftSymbol: "BTC"
            })
        );
    }

    function testCreateAccountWithUsernameFree() public {
        lensFactory.createAccountWithUsernameFree({
            metadataURI: "someMetadataURI",
            owner: address(this),
            accountManagers: new address[](0),
            accountManagersPermissions: new AccountManagerPermissions[](0),
            usernamePrimitiveAddress: address(username),
            username: "myTestUsername",
            createUsernameData: RuleExecutionData(new bytes[](0), new bytes[](0)),
            assignUsernameData: RuleExecutionData(new bytes[](0), new bytes[](0)),
            accountCreationSourceStamp: SourceStamp(address(0), 0, 0, ""),
            assignUsernameSourceStamp: SourceStamp(address(0), 0, 0, ""),
            createUsernameSourceStamp: SourceStamp(address(0), 0, 0, "")
        });
    }

    function testGraphFollowWithFactorySetup() public {
        IGraph graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "uri://any",
                owner: address(this),
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyExtraData()
            })
        );
        RuleExecutionData memory ruleExecutionDataArray = _emptyExecutionData();
        // bytes array with single empty element
        bytes[] memory singleElementByteArray = new bytes[](1);
        ruleExecutionDataArray.dataForRequiredRules = singleElementByteArray;
        graph.follow({
            followerAccount: address(this),
            targetAccount: address(0xc0ffee),
            followId: 0,
            graphRulesData: ruleExecutionDataArray,
            followRulesData: _emptyExecutionData(),
            sourceStamp: _emptySourceStamp()
        });
    }
}
