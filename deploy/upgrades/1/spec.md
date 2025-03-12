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
  - Overridden `createPost` function with custom logic
  - Overridden `editPost` through `_processPostEditingOnFeed` so nobody can call it.
    + `editPost` requires msg.sender == author
    + `_processPostEditingOnFeed` requires msg.sender == whitelisted address
  - Overridden `deletePost` function with msg.sender check removed and processDeletion() rules removed
  - Added `migration_force__setAuthorPostCount` function to set the author post count
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overridden functions (both `createPost` and postCount fix)

- Namespace: MigrationNamespace -> MigrationNamespace (with Name and Symbol setters)
  - Removed `EventEmitter` from the bytecode
  - Added `migration_force__setNameAndSymbol` function to set the name and symbol
  - Overridden `removeUsername` function with msg.sender check removed and processRemoval() rules removed
  - Overridden `assignUsername` function with msg.sender check removed and processAssigning() rules removed
  - Overridden `unassignUsername` function with msg.sender check removed and processUnassigning() rules removed
  - Overridden `_unassignIfAssigned` functions with process rules removed
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overridden functions
  - `createAndAssignUsername` only whitelisted multicall
  - `createUsername`
    + Add LensFactory to whitelisted addresses as well as multical


- Graph: MigrationGraph -> MigrationGraph (with overridden functions)
  - Removed `EventEmitter` from the bytecode
  - Overridden `follow` function with custom logic
  - Overridden `unfollow` function with msg.sender check removed and processUnfollow() rules removed
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overridden functions (both `follow` and `unfollow`)

- Account: MigrationAccount -> MigrationAccount (with overridden functions)
  - Removed `EventEmitter` from the bytecode
  - Overridden `setMetadataURI` function with `msg.sender` check removed
  - Overridden `addAccountManager` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overridden `removeAccountManager` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overridden `updateAccountManagerPermissions` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overridden `setExtraData` function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Overridden `executeTransactions` function with `msg.sender` check removed
  - Overridden `_transferOwnership` internal function with `onlyOwner` replaced with `onlyWhitelistedMulticall`
  - Added `onlyWhitelistedMulticall` modifier to migration-related and overridden functions

## Upgradeable (Final iteration):

### Beacons

- App: MigrationApp -> App (old code, but with event emitter removed, no migration-related functions left)

### TranaparentUpgradeableProxy

- AccessControlFactory: MigrationAccessControlFactory -> AccessControlFactory (old code, but with event emitter removed)

- AccountFactory: MigrationAccountFactory -> AccountFactory (old code, but with event emitter removed)

- AppFactory: MigrationAppFactory -> AppFactory (old code, but with event emitter removed)

- FeedFactory: MigrationFeedFactory -> FeedFactory (old code, but with event emitter removed)

- GraphFactory: MigrationGraphFactory -> GraphFactory (old code, but with event emitter removed)

- NamespaceFactory: MigrationNamespaceFactory -> NamespaceFactory (old code, but with event emitter removed)

## Again - Migration Upgrade 1 (fixes with restrictions, later to be removed)

- LensFactory: MigrationLensFactory -> MigrationLensFactory (old code, but with event emitter removed)
  - Add restriction to createAccountWithUsernameFree and deployAccount only by whitelisted multicall


## Non-upgradeable:

- Beacon

- Lock

These will forever have the EventEmitterEarly in the bytecode.
But in the code we remove it to keep the codebase clean for the other chains (Testnet even, etc)
