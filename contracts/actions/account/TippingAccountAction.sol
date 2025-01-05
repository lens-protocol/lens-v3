// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {BaseAccountAction} from "contracts/actions/account/base/BaseAccountAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";

contract TippingAccountAction is BaseAccountAction, MetadataBased {
    using SafeERC20 for IERC20;

    event Lens_Action_MetadataURISet(string metadataURI);

    /// @custom:keccak lens.param.amount
    bytes32 constant PARAM__TIP_AMOUNT = 0xc8a06abcb0f2366f32dc2741bdf075c3215e3108918311ec0ac742f1ffd37f49;
    /// @custom:keccak lens.param.token
    bytes32 constant PARAM__TIP_TOKEN = 0xee737c77be2981e91c179485406e6d793521b20aca5e2137b6c497949a74bc94;

    constructor(address actionHub, string memory metadataURI) BaseAccountAction(actionHub) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Action_MetadataURISet(metadataURI);
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
        require(tipAmount > 0);
        IERC20(erc20Token).safeTransferFrom(originalMsgSender, account, tipAmount);
        return "";
    }
}
