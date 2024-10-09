We decided to simplify the RuleCombinator for now (until we figure out something better):

- Rule Combinator doesn't have a Switch for OR and AND anymore
  - Instead, it has two sets of Rules: two arrays of Rules:
    - one for AND (executed first)
    - one for OR (executed if not empty, and if length > 1, the result is combined with OR)

Then we will have every Mandatory Rule (like usernameLength) in the AND array,
and every Optional Rule (for example: payToMint OR AdminApprovalToMint OR HoldNFTToMint) in the OR array.

This way we get rid of:

- complexity of the RuleCombinator
- complexity of combining multiple Combinators
- native settings of the primitives (like usernameLength) that become the Mandatory Rules
