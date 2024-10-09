// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {IAccessControl} from "./../../access-control/IAccessControl.sol";
// import {IUsernameRule} from "./../IUsernameRule.sol";

// // TODO: Replace this with an actual import if needed
// interface IERC20 {
//     function safeTransferFrom(address from, address to, uint256 value) external returns (bool);
// }

// contract UsernamePayToRegisterRule is IUsernameRule {
//     // Resource IDs involved in the contract
//     uint256 constant SKIP_PAYMENT_RID = uint256(keccak256("SKIP_PAYMENT"));
//     uint256 constant CONFIGURE_RULES_RID = uint256(keccak256("CONFIGURE_RULES"));

//     // Storage fields and structs
//     struct PaymentConfig {
//         address token;
//         uint256 amount;
//     }

//     struct AccessControl {
//         IAccessControl contractAddress;
//     }

//     address immutable IMPLEMENTATION;

//     constructor() {
//         IMPLEMENTATION = address(this);
//     }

//     // This is called directly
//     // TODO: Events
//     function configure(bytes calldata data) external override {
//         require(address(this) != IMPLEMENTATION); // Cannot initialize implementation contract
//         require(
//             $accessControl().contractAddress.hasAccess({
//                 account: msg.sender,
//                 resourceLocation: address(this),
//                 resourceId: CONFIGURE_RULES_RID
//             }),
//             "UsernamePayToRegisterRule: account is not allowed to configure this rule"
//         );
//         (address token, uint256 price) = abi.decode(data, (address, uint256));
//         $paymentConfig().token = token;
//         $paymentConfig().amount = price;
//         // if (accessControl != address($accessControl().contractAddress)) {
//         //     require(
//         //         $accessControl().contractAddress.hasAccess({
//         //             account: msg.sender,
//         //             resourceLocation: address(this),
//         //             resourceId: CHANGE_RULE_ACCESS_CONTROL_RID
//         //         }),
//         //         'UsernamePayToRegisterRule: access denied'
//         //     );
//         //     $accessControl().contractAddress = IAccessControl(accessControl);
//         // }
//     }

//     function processRegistering(address originalMsgSender, address account, string memory, bytes calldata)
//         external
//         override
//     {
//         if (
//             $accessControl().contractAddress.hasAccess({
//                 account: originalMsgSender,
//                 resourceLocation: address(this),
//                 resourceId: SKIP_PAYMENT_RID
//             })
//         ) {
//             return;
//         }
//         require(
//             IERC20($paymentConfig().token).safeTransferFrom(account, address(this), $paymentConfig().amount),
//             "UsernamePayToRegisterRule: transfer failed"
//         );
//     }

//     function processUnregistering(address, address, string memory, bytes calldata) external pure override {
//         return;
//     }

//     // Storage utility & helper functions

//     // keccak256('lens.username.access.control')
//     bytes32 constant ACCESS_CONTROL_STORAGE_SLOT = 0x8aa53012430d1b69e0c56a209604ece86bcb059649019c0b8452a3c3eabde61f;

//     // keccak256('lens.username.payment.config')
//     bytes32 constant PAYMENT_CONFIG_STORAGE_SLOT = 0x488b100e087724cce81ebca721f77c4d418e1319ae0393870c7a771d56311617;

//     function $accessControl() internal pure returns (AccessControl storage _accessControl) {
//         assembly {
//             _accessControl.slot := ACCESS_CONTROL_STORAGE_SLOT
//         }
//     }

//     function $paymentConfig() internal pure returns (PaymentConfig storage _paymentConfig) {
//         assembly {
//             _paymentConfig.slot := PAYMENT_CONFIG_STORAGE_SLOT
//         }
//     }
// }
