// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {OwnableMetadataBasedAccountAction} from "contracts/actions/account/base/OwnableMetadataBasedAccountAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract TippingAccountAction is OwnableMetadataBasedAccountAction, Initializable {
    using SafeERC20 for IERC20;

    /// @custom:keccak lens.param.amount
    bytes32 constant PARAM__TIP_AMOUNT = 0xc8a06abcb0f2366f32dc2741bdf075c3215e3108918311ec0ac742f1ffd37f49;
    /// @custom:keccak lens.param.token
    bytes32 public constant PARAM__TIP_TOKEN = 0xee737c77be2981e91c179485406e6d793521b20aca5e2137b6c497949a74bc94;

    constructor(address actionHub) OwnableMetadataBasedAccountAction(actionHub, address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedAccountAction._initialize(owner, metadataURI);
    }

    function _execute(address originalMsgSender, address account, KeyValue[] calldata params)
        internal
        override
        returns (bytes memory)
    {
        address erc20Token;
        uint256 tipAmount;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__TIP_AMOUNT) {
                tipAmount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == PARAM__TIP_TOKEN) {
                erc20Token = abi.decode(params[i].value, (address));
            }
        }
        require(tipAmount > 0, Errors.InvalidParameter());
        IERC20(erc20Token).safeTransferFrom(originalMsgSender, account, tipAmount);
        return "";
    }
}
