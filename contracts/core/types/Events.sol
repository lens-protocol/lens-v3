// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

library Events {
    event Lens_Contract_Deployed(string contractType, string flavour);

    event Lens_PermissionId_Available(uint256 indexed permissionId, string name);
}
