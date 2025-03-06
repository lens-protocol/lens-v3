// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";

library MockAccessControlLib {
    function testMockAccessControlLib() public {
        // Prevents being included in the foundry coverage report
    }

    function mockAccess(
        address accessControlledContract,
        address account,
        address contractAddress,
        uint256 permissionId,
        bool access
    ) internal {
        _getMockAccessControl(accessControlledContract).mockAccess(account, contractAddress, permissionId, access);
    }

    function mockCanChangeAccessControl(
        address accessControlledContract,
        address account,
        address contractAddress,
        bool canChange
    ) internal {
        _getMockAccessControl(accessControlledContract).mockCanChangeAccessControl(account, contractAddress, canChange);
    }

    function _getMockAccessControl(address accessControlledContract) private view returns (MockAccessControl) {
        return MockAccessControl(address(AccessControlled(accessControlledContract).getAccessControl()));
    }
}
