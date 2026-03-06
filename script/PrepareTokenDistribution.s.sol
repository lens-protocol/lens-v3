// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TokenDistributor} from "contracts/extensions/misc/TokenDistributor.sol";
import {KeyValue} from "contracts/extensions/misc/TokenDistributor.sol";

import {NATIVE_TOKEN, SELECTOR_BYTE_LENGTH} from "contracts/core/types/Constants.sol";

/// @dev Run this script using the following command:
///   forge script script/PrepareTokenDistribution.s.sol --zksync --suppress-warnings assemblycreate --rpc-url https://api.lens.matterhosted.dev/ -vvvvv
contract PrepareTokenDistribution is Script {
    /// @dev How many tokens should be allocated for each distribution period (e.g. you create a distribution with
    /// 10K GHO, with 1K sent each day, you would set it to 1_000e18)
    /// @custom:keccak lens.param.amount_allocated_per_batch
    bytes32 constant PARAM__AMOUNT_ALLOCATED_PER_BATCH =
        0x6b4066c61a2f7e3c5ca790dccaa57d2e863321fbf0584afe8095116695f3317f;

    /// How often distributions should occur in seconds (e.g. daily would be 86400)
    /// @custom:keccak lens.param.distribute_every
    bytes32 constant PARAM__DISTRIBUTE_EVERY = 0xd88adae0b656afd18030ea00aeb460a498a38b0dbf64dcdbfbeaa47f695e8fa5;

    /// @dev How often vesting should occur within each distribution period as a way to subdivide batches even further
    /// @dev Optional parameter
    /// @custom:keccak lens.param.vest_every
    bytes32 constant PARAM__VEST_EVERY = 0x869ebff7d31c711b87f50b1ce7da4c89f969ed5a032bb529fcdf5c2e5912a72f;

    /// @dev When should the token distribution begin
    /// @custom:keccak lens.param.starts_at
    bytes32 constant PARAM__STARTS_AT = 0x2de80238eb81ce97848edb5be4274576fea1a6760e422ef76cd8f100e3761c7e;

    /// @dev When should the token distribution end
    /// @custom:keccak lens.param.ends_at
    bytes32 constant PARAM__ENDS_AT = 0xcda52eac4bed4794dbef6554969a07005da129cf93e3faf0522856e765c7b774;

    address constant TOKEN_DISTRIBUTOR = 0x2a705184A6Bb7Dd185E4534d79E441B3edA1082c;

    address constant MULTISIG = 0xDA1F6A04fDF31b9B9AD4F6E4cc85Dcf1D5365DA6;

    function run() external {
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////////////////////////////////////////// S E T U P /////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // Native GHO
        address token = NATIVE_TOKEN;

        // 20 GHO
        uint256 totalAmountToAllocate = 20e18;

        // Extra parameters

        // 1 GHO
        uint256 amountAllocatedPerBatch = 1e18;

        // Distribute weekly
        uint256 distributeEvery = 10 minutes;

        // Start at: Wed Jul 23 2025 17:30:00 GMT+0000 - You can use https://www.unixtimestamp.com/
        uint256 startsAt = 1753291800;

        // End at: Wed Jul 23 2025 21:30:00 GMT+0000 - You can use https://www.unixtimestamp.com/
        uint256 endsAt = startsAt + 4 hours;

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        console.log("\nToken: ", token);
        console.log("\nTotal amount to allocate: ", totalAmountToAllocate);
        console.log("\n- - - - -");
        console.log("\nlens.param.amount_allocated_per_batch", amountAllocatedPerBatch);
        console.log("\nlens.param.distribute_every", distributeEvery);
        console.log("\nlens.param.starts_at", startsAt);
        console.log("\nlens.param.ends_at", endsAt);

        KeyValue[] memory params = new KeyValue[](4);
        params[0] = KeyValue({key: PARAM__AMOUNT_ALLOCATED_PER_BATCH, value: abi.encode(amountAllocatedPerBatch)});
        params[1] = KeyValue({key: PARAM__DISTRIBUTE_EVERY, value: abi.encode(distributeEvery)});
        params[2] = KeyValue({key: PARAM__STARTS_AT, value: abi.encode(startsAt)});
        params[3] = KeyValue({key: PARAM__ENDS_AT, value: abi.encode(endsAt)});

        bytes memory encodeCall =
            abi.encodeCall(TokenDistributor.createDistribution, (token, totalAmountToAllocate, params));

        console.log("\n\n\nFull calldata: \n");
        console.logBytes(encodeCall);

        console.log("\n\n\nCalldata without selector: \n");
        console.logBytes(_getCalldataWithoutSelector(encodeCall));

        _handleMultisigBalance(totalAmountToAllocate);

        vm.prank(MULTISIG);
        (bool success, bytes memory data) = address(TOKEN_DISTRIBUTOR).call{value: totalAmountToAllocate}(encodeCall);

        if (success) {
            uint256 distributionId = abi.decode(data, (uint256));
            console.log("\n\n\nDistribution ID: \n");
            console.log(distributionId);
        } else {
            revert("Failed to create distribution");
        }
    }

    function _handleMultisigBalance(uint256 totalAmountToAllocate) internal {
        uint256 multisigBalance = address(MULTISIG).balance;

        console.log("\n\n\nMultisig balance: \n");
        console.log(multisigBalance);

        if (multisigBalance < totalAmountToAllocate) {
            string memory answer = vm.prompt(
                "\nMultisig does not have enough balance. Do you want to increase the balance for this tx simulation? (Y/n)"
            );
            if (keccak256(bytes(answer)) == keccak256(bytes("Y")) || bytes(answer).length == 0) {
                vm.deal(MULTISIG, totalAmountToAllocate);
            } else {
                revert("\nYou need to top up the multisig balance to run this in production");
            }
        } else {
            console.log("\nMultisig has enough balance to run this in production");
        }
    }

    function _getCalldataWithoutSelector(bytes memory encodeCall) public pure returns (bytes memory) {
        bytes memory calldataWithoutSelector = new bytes(encodeCall.length - SELECTOR_BYTE_LENGTH);
        for (uint256 i = SELECTOR_BYTE_LENGTH; i < encodeCall.length; i++) {
            calldataWithoutSelector[i - SELECTOR_BYTE_LENGTH] = encodeCall[i];
        }
        return calldataWithoutSelector;
    }
}
