## Upgrade 1 (fixes introduced, later to be removed)

### WhitelistedMulticall

- We need to deploy a new Multicall contract that is only allowed to be called by Whitelisted senders.
  - We deploy it from an empty wallet, so the nonce is 0 (from `0x56EDD365d9b00C82E5D3C09e5A295224e076321c`)
  - The Multicall will be Upgradeable so the Whitelisted Senders list can be updated.
  - The Multicall Implementation address will be `0x0Ac587520A86688a4af0E9202C6BFf6Ff68db104` (nonce 0)
  - The Multicall Proxy address will be `0xC9A7A3762cC1073b40B19f7A333c046ce464e8Db` (nonce 1)

### Beacons

- Feed: MigrationFeed -> MigrationFeed (with some fixes)
  - Removed the `EventEmitter` from the bytecode
  - Overriden `createPost` function with custom logic
  - Overriden `editPost` through `_processPostEditingOnFeed` so nobody can call it.
    + `editPost` requires msg.sender == author
    + `_processPostEditingOnFeed` requires msg.sender == whitelisted address
  - Overriden `deletePost` function with msg.sender check removed and processDeletion() rules removed
  - Added `migration_force__setAuthorPostCount` function to set the author post count
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overriden functions (both `createPost` and postCount fix)

- Namespace: MigrationNamespace -> MigrationNamespace (with Name and Symbol setters)
  - Removed `EventEmitter` from the bytecode
  - Added `migration_force__setNameAndSymbol` function to set the name and symbol
  - Overriden `removeUsername` function with msg.sender check removed and processRemoval() rules removed
  - Overriden `assignUsername` function with msg.sender check removed and processAssigning() rules removed
  - Overriden `unassignUsername` function with msg.sender check removed and processUnassigning() rules removed
  - Overriden `_unassignIfAssigned` functions with process rules removed
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overriden functions
  - `createAndAssignUsername` only whitelisted multicall
  - `createUsername`
    + Add LensFactory to whitelisted addresses as well as multical


- Graph: MigrationGraph -> MigrationGraph (with overriden functions)
  - Removed `EventEmitter` from the bytecode
  - Overriden `follow` function with custom logic
  - Overriden `unfollow` function with msg.sender check removed and processUnfollow() rules removed
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overriden functions (both `follow` and `unfollow`)

- Account: MigrationAccount -> MigrationAccount (with overriden functions)
  - Removed `EventEmitter` from the bytecode
  - Overriden `setMetadataURI` function with `msg.sender` check removed
  - Overriden `addAccountManager` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overriden `removeAccountManager` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overriden `updateAccountManagerPermissions` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overriden `setExtraData` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overriden `executeTransactions` function with `msg.sender` check removed
  - Overriden `_transferOwnership` internal function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overriden functions

## Upgradeable (Final iteration):

### TranaparentUpgradeableProxy

- AccessControlFactory: MigrationAccessControlFactory -> AccessControlFactory (old code, but with event emitter removed)

- AccountFactory: MigrationAccountFactory -> AccountFactory (old code, but with event emitter removed)

- AppFactory: MigrationAppFactory -> AppFactory (old code, but with event emitter removed)

- FeedFactory: MigrationFeedFactory -> FeedFactory (old code, but with event emitter removed)

- GraphFactory: MigrationGraphFactory -> GraphFactory (old code, but with event emitter removed)

- NamespaceFactory: MigrationNamespaceFactory -> NamespaceFactory (old code, but with event emitter removed)

- LensFactory: MigrationLensFactory -> MigrationLensFactory (old code, but with event emitter removed)
  - Add restriction to createAccountWithUsernameFree and deployAccount only by whitelisted multicall

### Beacons

- App: MigrationApp -> App (old code, but with event emitter removed, no migration-related functions left)

---

## Non-upgradeable:

- Beacon

- Lock

These will forever have the EventEmitterEarly in the bytecode.
But in the code we remove it to keep the codebase clean for the other chains (Testnet even, etc)
