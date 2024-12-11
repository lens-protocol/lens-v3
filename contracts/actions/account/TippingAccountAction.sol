// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccountAction} from "./../../core/interfaces/IAccountAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract TippingAccountAction is IAccountAction {
    using SafeERC20 for IERC20;

    // keccak256("lens.actions.account.TippingAccountAction.param.key.tipAmount");
    bytes32 immutable TIP_AMOUNT_PARAM_KEY = 0x9c3dd1983546cd2f985b2e6692b416f4157648b3750ffc5bdf5a6365061d9bd9;
    // keccak256("lens.actions.account.TippingAccountAction.param.key.tipToken");
    bytes32 immutable TIP_TOKEN_PARAM_KEY = 0xae0b2bf062e67ee8e231397eadff68e32752f185a8cb19379ed8cfa87ae7bd08;

    function configure(
        address, /* account */
        KeyValue[] calldata /* params */
    ) external pure override returns (bytes memory) {
        revert(); // Configuration not needed for tipping.
    }

    function execute(address account, KeyValue[] calldata params) external override returns (bytes memory) {
        address erc20Token;
        uint256 tipAmount;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == TIP_AMOUNT_PARAM_KEY) {
                tipAmount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == TIP_TOKEN_PARAM_KEY) {
                erc20Token = abi.decode(params[i].value, (address));
            }
        }
        require(tipAmount > 0);
        IERC20(erc20Token).safeTransferFrom(msg.sender, account, tipAmount);
        emit Lens_AccountAction_Executed(account, params);
        return "";
    }
}
