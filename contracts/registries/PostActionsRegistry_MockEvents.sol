// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PostActionsRegistry {
    // This is emitted when a DEV signals they developed a new PostAction that someone can use
    event Lens_PostAction_Registered(address indexed action, string metadataURI);
}
