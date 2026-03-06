// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {ILensFees, LensFeesData} from "contracts/extensions/fees/LensFees.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CONTRACT__LENS_FEES, NATIVE_TOKEN, BPS_MAX} from "contracts/core/types/Constants.sol";
import {RecipientData} from "contracts/core/types/Types.sol";
import {LENS_CREATE_2_ADDRESS, ILensCreate2} from "contracts/core/upgradeability/LensCreate2.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract LensPaymentHandler {
    using SafeERC20 for IERC20;

    address immutable LENS_FEES;

    constructor() {
        LENS_FEES = ILensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_FEES);
    }

    function _handlePayment(
        address payer,
        address token,
        uint256 amount,
        RecipientData[] memory recipients,
        RecipientData[] memory referrals,
        uint16 referralFeeBps
    ) internal virtual {
        uint256 remainingAmount = _processTreasuryFee(payer, token, amount);
        remainingAmount = _processReferralFees(payer, token, remainingAmount, referrals, referralFeeBps);
        _processRecipients(payer, token, remainingAmount, recipients);
    }

    function _handlePayment(
        address payer,
        address token,
        uint256 amount,
        address recipient,
        RecipientData[] memory referrals,
        uint16 referralFeeBps
    ) internal virtual {
        uint256 remainingAmount = _processTreasuryFee(payer, token, amount);
        remainingAmount = _processReferralFees(payer, token, remainingAmount, referrals, referralFeeBps);
        _processRecipient(payer, token, remainingAmount, recipient);
    }

    function _processTreasuryFee(address payer, address token, uint256 amount) internal virtual returns (uint256) {
        LensFeesData memory lensFees = ILensFees(LENS_FEES).getLensFeesData();
        uint256 amountForTreasury = (amount * lensFees.treasuryFeeBps) / BPS_MAX;
        if (lensFees.treasuryAddress != address(0) && amountForTreasury > 0) {
            _sendToken(token, payer, lensFees.treasuryAddress, amountForTreasury);
        }
        return amount - amountForTreasury;
    }

    function _processReferralFees(
        address payer,
        address token,
        uint256 amount,
        RecipientData[] memory referrals,
        uint16 referralFeeBps
    ) internal virtual returns (uint256) {
        uint256 totalAmountForReferrals = (amount * referralFeeBps) / BPS_MAX;
        if (totalAmountForReferrals == 0 || referrals.length == 0) {
            return amount;
        }
        uint16 accumulatedSplitBps;
        uint256 accumulatedAmountForReferrals;
        for (uint256 i = 0; i < referrals.length; i++) {
            uint256 amountForReferral = (totalAmountForReferrals * referrals[i].splitBps) / BPS_MAX;
            accumulatedSplitBps += referrals[i].splitBps;
            accumulatedAmountForReferrals += amountForReferral;
            if (amountForReferral > 0) {
                _sendToken(token, payer, referrals[i].recipient, amountForReferral);
            }
        }
        require(accumulatedSplitBps <= BPS_MAX);
        require(accumulatedAmountForReferrals <= totalAmountForReferrals);
        return amount - accumulatedAmountForReferrals;
    }

    function _processRecipient(address payer, address token, uint256 amount, address recipient) internal virtual {
        if (amount > 0) {
            _sendToken(token, payer, recipient, amount);
        }
    }

    function _processRecipients(address payer, address token, uint256 amount, RecipientData[] memory recipients)
        internal
        virtual
    {
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amountForRecipient = (amount * recipients[i].splitBps) / BPS_MAX;
            if (amountForRecipient > 0) {
                _sendToken(token, payer, recipients[i].recipient, amountForRecipient);
            }
        }
    }

    function _sendToken(address token, address payer, address recipient, uint256 amount) internal virtual {
        if (token == NATIVE_TOKEN) {
            (bool success,) = payable(recipient).call{value: amount}("");
            require(success, Errors.FailedToTransferNative());
        } else {
            IERC20(token).safeTransferFrom(payer, recipient, amount);
        }
    }

    function _validateToken(address token) internal view virtual {
        if (token != NATIVE_TOKEN) {
            // Expects token to support ERC-20 interface, we call balanceOf and expect it to not revert
            IERC20(token).balanceOf(address(this));
        }
    }
}
