// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {SimpleCollectAction} from "contracts/actions/post/collect/SimpleCollectAction.sol";

contract MockSimpleCollectAction is SimpleCollectAction {
    function $collectDataStorage2() private pure returns (CollectActionStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__SIMPLE_COLLECT_ACTION
        }
    }

    constructor(address actionHub) SimpleCollectAction(actionHub) {}

    function setCollectionAddress(address feed, uint256 postId, address collectionAddress) external {
        $collectDataStorage2().collectData[feed][postId].collectionAddress = collectionAddress;
    }
}
