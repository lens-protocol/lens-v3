// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IFollowGraph} from "./IFollowGraph.sol";
import {IGraphExtension} from "./IGraphExtension.sol";
import {IFollowModule} from "./IFollowModule.sol";

contract ERC721 {
    mapping(uint256 => address) internal _ownerOf;

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _ownerOf[tokenId];
    }

    function _mint(address to, uint256 tokenId) internal {
        _ownerOf[tokenId] = to;
    }

    function _burn(uint256 tokenId) internal {
        _ownerOf[tokenId] = address(0);
    }
}

// We build this a way of testing the FollowGraph design.
// We want to test two things, which will be forced in the code, but are not required at all:
// 1- Follow tokenization
// 2- Graph extension as the single entry-point for the FollowGraph (that's why it will implement the IFollowGraph)
//
// This contract will be set up on-top of the core FollowGraph but also set as extension (so, also "under" it).
contract FollowTokenizer is ERC721, IGraphExtension, IFollowGraph {
    IFollowGraph private _followGraph;

    mapping(uint256 => address) internal _followApproval;

    constructor(IFollowGraph followGraph) {
        _followGraph = followGraph;
    }

    // IGraphExtension implementation

    function initialize(bytes calldata data) external {
        // Not needed. Unless we want to replace the constructor.
    }

    function processFollow(
        address originalMsgSender,
        address followerAcount,
        address accountToFollow,
        uint256 followId,
        bytes calldata data
    ) external {
        if (originalMsgSender != address(this)) {
            // This graph extension forces itself to be the entry-point for the FollowGraph.
            revert();
        }
        if (data.length > 0) {
            // Decode tokenization receiver and mint the follow token there
        }
    }

    // TODO: Should this exist? Maybe not, so it cannot prevent the unfollow...
    // Maybe the function should exist but not being called by `unfollow` but by the user in a separate tx later.
    // We could even do wrappers for this, given that all the accounts are smart contracts
    function processUnfollow(
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        uint256 followId,
        bytes calldata data
    ) external {
        // TODO: Oh shit! This is not called during unfollow :)
        // How can we restrict this as single entry-point then...?
        // --------------------------------------------------------------
        // Maybe processUnfollow should be called at the GraphExtension, as it is a global-graph module. It should just
        // not be called for the FollowModules, which are individual per-user, and then users can program them to avoid
        // people unfollowing them; but, if the "permanent follow" is a graph feature, then maybe that is Ok...
    }

    // TODO: Should the block be global? Or at least have a global registry to signal it too...
    function processBlock(address account, bytes calldata data) external {}

    function processUnblock(address account, bytes calldata data) external {}

    function processFollowModuleChange(
        address account,
        IFollowModule followModule,
        bytes calldata followModuleInitData,
        bytes calldata data
    ) external {
        // It does not set any restriction over the follow modules that can be used.
        return;
    }

    // IFollowGraph implementation, as this extension will be set as a wrapper entry-point.

    function follow(
        address followerAccount,
        address accountToFollow,
        uint256 followId,
        bytes calldata graphExtensionData,
        bytes calldata followModuleData
    ) public {
        if (followerAccount != msg.sender) {
            revert();
        }
        if (followId != 0) {
            // TODO: We need to implement the case where NFT wasn't minted and there is no ownerOf, but ID was freed through unfollow.
            if (_ownerOf[followId] != followerAccount) {
                if (_followApproval[followId] != followerAccount) {
                    revert();
                }
                delete _followApproval[followId]; // TODO: Should we delete even when following without using this?
            }
            address currentFollower = _followGraph.getFollowerById(accountToFollow, followId);
            if (currentFollower != address(0)) {
                // Execute an unfollow on behalf of current follower...
                _followGraph.unfollow(currentFollower, accountToFollow, new bytes(0));
            }
        }
        _followGraph.follow(followerAccount, accountToFollow, followId, graphExtensionData, followModuleData);
    }

    function unfollow(address followerAccount, address accountToUnfollow, bytes calldata graphExtensionData) public {
        if (followerAccount != msg.sender) {
            uint256 followId = _followGraph.getFollow(followerAccount, accountToUnfollow).id;
            if (_ownerOf[followId] != msg.sender) {
                revert();
            }
        }
        _followGraph.unfollow(followerAccount, accountToUnfollow, graphExtensionData);
    }

    function follow(address accountToFollow, bytes calldata graphExtensionData, bytes calldata followModuleData)
        external
    {
        _followGraph.follow(msg.sender, accountToFollow, 0, graphExtensionData, followModuleData);
    }

    function unfollow(address accountToUnfollow, bytes calldata graphExtensionData) external {
        _followGraph.unfollow(msg.sender, accountToUnfollow, graphExtensionData);
    }

    function isFollowing(address followerAccount, address targetAccount) external view returns (bool) {
        return _followGraph.isFollowing(followerAccount, targetAccount);
    }

    function getFollowerById(address account, uint256 followId) external view returns (address) {
        return _followGraph.getFollowerById(account, followId);
    }

    function getFollow(address followerAccount, address followedAccount) external view returns (Follow memory) {
        return _followGraph.getFollow(followerAccount, followedAccount);
    }

    function getFollowModule(address account) external view returns (IFollowModule) {
        return _followGraph.getFollowModule(account);
    }

    function getPermissions(address account) external view returns (Permissions memory) {
        return _followGraph.getPermissions(account);
    }

    function getFollowersCount(address account) external view returns (uint256) {
        return _followGraph.getFollowersCount(account);
    }

    function getAdmin() external view returns (address) {
        return _followGraph.getAdmin();
    }

    function getGraphExtension() external view returns (IGraphExtension) {
        return _followGraph.getGraphExtension(); // TODO: Maybe should do some extra check...
    }
}
