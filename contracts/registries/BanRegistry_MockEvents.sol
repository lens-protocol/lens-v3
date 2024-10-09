// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO: We should think about better naming
contract BanRegistry {
    // USER PvP Blocking
    ////////////////////
    // Scoped - Scope can be Global(0x0), an App, a Primitive, or anything else. Then you can query block state by scope!
    event Lens_BanRegistry_AccountBlocked(address indexed source, address indexed target, address indexed scope);
    event Lens_BanRegistry_AccountUnblocked(address indexed source, address indexed target, address indexed scope);
    ////////////////////

    // BANNING on PRIMITIVE/APP LEVEL
    /////////////////////////////////
    // Global ban on all (enrolled) primitives & apps
    event Lens_BanRegistry_Banned(address indexed account, address indexed scope);
    event Lens_BanRegistry_Unbanned(address indexed account, address indexed scope);
}
