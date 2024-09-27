# Profile Managers in V3

=-----------------------

In V2 Profile managers had very rigid functionality before, that was defined by Lens developers and stayed like that forever.

In V3, as every Profile is an Account, we can introduce very interesting concepts of Managing the Profile, which can be
very customizable and powerful, because Smart Accounts are smart-contracts with their own rules and logic.

## Account Access Control

We can interoduce a concept of Account Access Control, which can be plugged into any Account.
Account can restrict or allow certain functions to be executed by certain users.

For example, a set of PERMISSIONS we can define for an Account:

- `MANAGE_PROFILE` - allows to change Profile metadata, picture, description, etc
- `MANAGE_POSTS` - allows to create, edit and remove posts
- `MANAGE_FOLLOWERS` - allows to follow/unfollow other accounts
- `MANAGE_COMMUNITIES` - allows to join/leave communities
- etc

The Permissions (called ResourseIDs in our AccessControl implementation) can be more granular (`CREATE_POST`, `EDIT_POST`, `DELETE_POST`).

Each Permission would only allow to call certain functions onBehalf of the Account, like:
`MANAGE_FOLLOWERS` would allow to call:

- follow(...)
- unfollow(...)
- etc

`MANAGE_POSTS` would allow to call:

- createPost(...)
- editPost(...)
- deletePost(...)
- etc

## Account Access Control Usage

A user would grant some Permissions to some Address, like:
0xALICE is allowed to: `MANAGE_PROFILE`, `MANAGE_POSTS`, but nothing else
0xBOB is allowed to: `MANAGE_FOLLOWERS`, `MANAGE_COMMUNITIES`, but nothing else

Then, when 0xALICE calls `editProfile(...)` function on the Account, the Account would check if 0xALICE has `MANAGE_PROFILE` Permission, and only then allow to execute the function.

## Discussion & Ideas

```
function genericAccountCall(address target, bytes memory callData, uint256 value) {
    bytes4 selector = callData.firstFourBytes();
    require(msg.sender == owner() || _hasAccess({resourceLocation: target, resourceId: selector}));
    if (msg.sender != owner() && value > 0) {
        _requireAccess("SEND_MONEY");
    }
    target.call{value: value}(callData);
}

signature = "transfer(address,address,uint256)"

function _grantAccess(resourceLocation, string memory signature) {
    bytes32 resourceId = keccak256(abi.encodePacked(signature));
    0x12346719826348172639487612398476129837461293784

    but bytes4 selector = 0x12345678
}

function _grantAccess(resourceLocation, string memory signature) {
    bytes32 resourceId = bytes4(keccak256(abi.encodePacked(signature)));
    in mapping: 0x1234678

    but bytes4 selector = 0x12345678
}

function _hasAccess(ResourceLocation location, bytes4 selector) {
    resourceId = 4 bytes
    return _permissions[location][];
}

in storage mapping we have resourseID as: 0x1234876129384761293874619283764981237649871236
in function param we only recieve selector as: 0x12345678
how do we do _permissions[location][selector] lookup?
```

====

We pass the bytes4 selector as an RID, and we pass the Primitive address as a loncation.
We can have wildcards that can mean any RID (maybe 0x0? or keccak256("")?) and any location (0x0? or keccak256("")).
And then the AccessControl can check all these.
