// SPDX-License-Identifier: GPL-3.0-only

// function deployAccount(
//     address owner, 0xB2b033701F9FbcF51ce3e4866C6605aCE3a4f3C7
//     string calldata metadataURI, "https://devnet.irys.xyz/GLzhFVr9nAQ7svCzJds2TNiJXeCBf3NVgT82XZuBUsch"
//     address[] calldata accountManagers, [0x00A58BA275E6BFC004E2bf9be121a15a2c543e71]
//     AccountManagerPermissions[] calldata accountManagersPermissions, [(true, false, false, true)]
//     SourceStamp calldata sourceStamp (0x0000000000000000000000000000000000000000, 0, 0, 0x)
// ) external returns (address) {

import { emptySourceStamp } from './deployAux';
import { verifyDeployedContract } from './utils';
import * as hre from 'hardhat';

const owner = '0xB2b033701F9FbcF51ce3e4866C6605aCE3a4f3C7';
const metadataURI = 'https://devnet.irys.xyz/GLzhFVr9nAQ7svCzJds2TNiJXeCBf3NVgT82XZuBUsch';
const accountManagers = ['0x00A58BA275E6BFC004E2bf9be121a15a2c543e71'];
const accountManagersPermissions = [
  {
    canExecuteTransactions: true,
    canTransferTokens: false,
    canTransferNative: false,
    canSetMetadataURI: true,
  },
];
const sourceStamp = emptySourceStamp;

export default async function () {
  const deployedAddress = '0x58F05d2d64e168d491C30dDDe58585784d411A91';
  const deployedArtifact = await hre.artifacts.readArtifact('Account');

  await verifyDeployedContract({
    address: deployedAddress,
    artifact: deployedArtifact,
    constructorArguments: [
      owner,
      metadataURI,
      accountManagers,
      accountManagersPermissions,
      sourceStamp,
    ],
  });
}
