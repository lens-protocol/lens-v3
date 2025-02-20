// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

library Errors {
    error AccessDenied();
    error AllAnyOfRulesReverted();
    error AlreadyExists();
    error AlreadyInitialized();
    error AutoUpgradeEnabled();
    error Banned();
    error Blocked();
    error CannotFollowAgain();
    error CannotHaveRules();
    error CannotStartWithThat();
    error ConfigureCallReverted();
    error Disabled();
    error DoesNotExist();
    error DuplicatedValue();
    error Expired();
    error Immutable();
    error InvalidConfigSalt();
    error InvalidMsgSender();
    error InvalidParameter();
    error InvalidSignature();
    error LimitReached();
    error Locked();
    error NonceUsed();
    error NotAContract();
    error NotAllowed();
    error NotAMember();
    error NotEnough();
    error NotFollowing();
    error NotFound();
    error NotImplemented();
    error RedundantStateChange();
    error RequiredRuleReverted();
    error RuleNotConfigured();
    error SelectorEnabledForDifferentRuleType();
    error ActionOnSelf();
    error SingleAnyOfRule();
    error UnexpectedContractImpl();
    error UnexpectedValue();
    error UnsupportedSelector();
    error Untrusted();
    error UsernameAssigned();
    error WrongSigner();
}
