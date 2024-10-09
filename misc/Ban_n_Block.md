## Bans & Blocks can be the following:

BLOCKING [Done by an user to block user]

- Global block: Done by the user in the BanRegistry and applies to everything.
- App block: Done by the user in the BanRegistry but applies only to an specific app.

BANNING [Done by an app or primitive to a user]

- [*] Global ban (non-binding): Flagged by some mechanism and can be opted-in to be consumed (I'd say not on 1st protocol release, requires the mechanism to be built)
- App ban: Done by the app so a user cannot use the primitives belonging to this app.
- Primitive ban: Done by the primitive (their owners, DAO behind it, etc) so a user cannot use this primitive.

--
Technical Implementation of this:

- BanRegistry: A contract that holds the bans and blocks.
  It can store all the data, basically a mapping or smth like that. (TODO: Explore how exactly)
- BanRule: A common rule that any primitive can plug&play to support the bans & blocks.

--
Notes:

- This Scoped approach with Apps/Primitives applying the BanRule IS NOT BINDING.
  This means that if one User wants to ban another User everywhere, then the App should also support that.
  If the app doesn't support it (or does not WANT to support it intentionally) - then banned User might still interact with the banning user.
