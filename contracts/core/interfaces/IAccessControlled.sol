// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

interface IAccessControlled {
    function getAccessControl() external view returns (IAccessControl);
}
