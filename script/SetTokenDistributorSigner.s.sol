// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TokenDistributor} from "contracts/extensions/misc/TokenDistributor.sol";

/// @dev Run this script using the following command:
///   forge script script/SetTokenDistributorSigner.s.sol --rpc-url <RPC_URL> --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract SetTokenDistributorSigner is Script {
    function run() external {
        TokenDistributor tokenDistributor = TokenDistributor(0x2a705184A6Bb7Dd185E4534d79E441B3edA1082c);

        uint256 pk = vm.envUint("WALLET_PRIVATE_KEY");

        vm.startBroadcast(pk);

        tokenDistributor.updateSigner(0x801Bc450BAde425745434e9147eFEe16cA169dC2);

        vm.stopBroadcast();
    }
}
