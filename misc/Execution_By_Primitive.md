// TODO: Consider if the following idea is worth it

The following idea is about how to link/execute by different primitive, signalling that this primitive did something:

Every primitive should have an `execute()` function (or `executeCall()`).

This should just perform a call from the Primitive as msg.sender

This call should follow checking AccessControl (`canExecute` permission), and onlyOwner should be probably allowed to call it.
