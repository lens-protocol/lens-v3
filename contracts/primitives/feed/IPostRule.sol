// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RuleConfiguration} from "./../../types/Types.sol";

// TODO: We do not have native referrals here, shoud we add them?
interface IPostRule {
    function configure(uint256 postId, bytes calldata data) external;

    function processQuote(uint256 quotedPostId, uint256 childPostId, bytes calldata data) external;

    function processParent(uint256 parentPostId, uint256 childPostId, bytes calldata data) external;

    function processChildPostRulesChanged(
        uint256 parentPostId,
        uint256 postId,
        RuleConfiguration[] calldata newChildPostRulesData,
        bytes calldata data
    ) external;
}

/*

Problem #1:

Someone posts something with some rules for Quoting that say - quotes must have the same rules
And adding rules & posting is separate (two txs)

Someone quotes this post with createPost
but then how do we check they will also send a second TX to add the same rules?

--

Problem #2:

- if we don't have global requirement of the rules being the same for something
then how do you enforce the same rules down the chain of interactions?

Example: Only my followers can reply! (this only works if you enforce replies to your post to have this rule there too)

We don't have a rootID here like we had in LensV2. Maybe we need RootPostID?

--

Problem #3:

Now we can also edit the post rules. If it enforces it during the adding, we also need to enforce it during the editing
and deletion of rules

==

Maybe there should be some rule that is like "Copy parent rules" or whatever, and it does not allow to remove this rule.
So when you try to remove it, it reverts. Or even some "clone" rule, that will process the rules as if they were the parent/quoted.

^ this might work

1) You can have a rule that requires the quote postParams to have only one CloneRule, and nothing else
2) When you delete or edit or add rules - you need to do processRuleChanges, like in the Graph - and the CloneRule will prevent these
3) When someone else quotes your quote with a CloneRule - they would be forced to do the same by the CloneRule itself

--

But this would only work if the Rules are stored and changed inside the Post/PostParams, right?
We cannot have 2 txs approach for for this, right?

Right, it is not possible to enforce this with 2 txs, because someone can frontrun.

--

The vision for this right now is:
1) We still have addPostRules,  upfdatePostRules, deletePostRules, which will be able to add/update/delete rules from a post
2) The createPost will automatically call addPostRules (so we can enforce the CloneRule by calling processRulesChanged)
3) The editPost and deletePost will not have changing PostRules logic - if you want to change the rules you need to call
   editPostRules/deletePostRules
4) createPost
*/
