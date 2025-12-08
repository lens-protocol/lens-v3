const fs = require('fs');
const { ethers } = require('ethers');
const crypto = require('crypto');

// Get addressBook file from command line argument, default to mainnet
const addressBookFile = process.argv[2] || 'addressBook.mainnet.json';
const shouldUpdateAddressBook = process.argv.includes('--update');

console.log(`Using addressBook: ${addressBookFile}`);
if (shouldUpdateAddressBook) {
  console.log('Will update addressBook with on-chain values');
}

// Constants for storage slots
const EIP1967_ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
const EIP1967_IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
const BEACON_SLOT = '0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50';
const BEACON_DEFAULT_VERSION_SLOT = 1; // Storage slot for default version in Beacon contract

// Contract type names for reporting
const ContractTypeNames = {
  0: 'Implementation',
  1: 'Beacon',
  2: 'Factory',
  3: 'Primitive',
  4: 'Aux',
  5: 'Action',
  6: 'Rule',
  7: 'Misc',
  8: 'Address'
};

// AccessControl type hash to human-readable name mapping (lowercase keys for case-insensitive lookup)
const AccessControlTypeNames = {
  '0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb': 'OwnerAdminOnlyAccessControl',
  '0xd7f02d8d0f478fc8e4dfbe64bafebbee03e9d359c4395bdbf35858b495f3daaa': 'RoleBasedAccessControl',
  '0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae': 'PermissionlessAccessControl'
};

// ABIs for common functions
const ownerABI = ['function owner() view returns (address)'];
const implementationABI = ['function implementation() view returns (address)'];
const accessControlABI = ['function getAccessControl() view returns (address)'];
const getTypeABI = ['function getType() view returns (bytes32)'];
const proxyAdminABI = ['function proxy__getProxyAdmin() view returns (address)'];
const proxyImplABI = ['function proxy__getImplementation() view returns (address)'];
const effectiveImplABI = ['function proxy__getEffectiveImplementation() view returns (address)'];
const beaconABI = ['function proxy__getBeacon() view returns (address)'];
const autoUpgradeABI = ['function proxy__getAutoUpgrade() view returns (bool)'];
const lockABI = ['function isLocked() view returns (bool)'];

// Function to calculate bytecodeHash, ported from lensUtils.ts
function calculateBytecodeHash(bytecode) {
  // Remove '0x' prefix if present
  const cleanBytecode = bytecode.startsWith('0x') ? bytecode.slice(2) : bytecode;

  // Convert hex string to byte array
  const byteArray = Buffer.from(cleanBytecode, 'hex');

  // Calculate SHA256 hash
  const hash = Buffer.from(crypto.createHash('sha256').update(byteArray).digest());

  // Modify first 4 bytes according to spec
  hash[0] = 1;
  hash[1] = 0;

  // Set bytes 2-3 to length/32 as uint16
  const lenBytes = Buffer.alloc(2);
  lenBytes.writeUInt16BE(byteArray.length / 32);
  hash[2] = lenBytes[0];
  hash[3] = lenBytes[1];

  return '0x' + hash.toString('hex');
}

async function getContractBytecodeHash(provider, contractAddress) {
  try {
    const bytecode = await provider.getCode(contractAddress);
    if (bytecode === '0x') return '-'; // No bytecode, probably an EOA
    return calculateBytecodeHash(bytecode);
  } catch (error) {
    console.error(`Error getting bytecode hash for ${contractAddress}:`, error.message);
    return '-';
  }
}

async function isContract(provider, address) {
  try {
    const code = await provider.getCode(address);
    return code !== '0x';
  } catch {
    return false;
  }
}

function normalizeHex(value) {
  if (value === undefined || value === null || value === '' || value === '-') {
    return null;
  }
  let str = String(value).toLowerCase();
  // Remove 0x prefix for comparison
  if (str.startsWith('0x')) {
    str = str.slice(2);
  }
  return str;
}

function compareValues(onChain, addressBook, fieldName) {
  if (addressBook === undefined || addressBook === null || addressBook === '') {
    return { match: 'N/A', onChain, addressBook: '-' };
  }
  if (onChain === '-' || onChain === undefined || onChain === null) {
    return { match: 'N/A', onChain: '-', addressBook };
  }

  // Normalize for comparison (handles 0x prefix differences)
  const normalizedOnChain = normalizeHex(onChain);
  const normalizedAddressBook = normalizeHex(addressBook);

  const match = normalizedOnChain === normalizedAddressBook;
  return { match: match ? '✓' : '✗', onChain, addressBook };
}

async function main() {
  // Read addressBook
  const addressBook = JSON.parse(fs.readFileSync(addressBookFile, 'utf8'));

  // Setup provider with the Lens RPC URL
  const provider = new ethers.JsonRpcProvider('https://rpc.lens.xyz');

  // CSV headers
  const csvHeaders = [
    'ContractType', 'ContractName', 'Address',
    // Ownership
    'Owner_OnChain', 'Owner_AddressBook', 'Owner_Match',
    // Proxy Info
    'ProxyType',
    'ProxyAdmin_OnChain', 'ProxyAdmin_AddressBook', 'ProxyAdmin_Match',
    'ProxyAdminIsContract', 'ProxyAdminOwnerType', 'ProxyAdminOwner',
    // Implementation
    'Implementation_OnChain', 'Implementation_AddressBook', 'Implementation_Match',
    // Beacon specific
    'Beacon', 'BeaconOwner', 'BeaconDefaultVersion',
    // BeaconProxy specific
    'AutoUpgrade',
    // Lock specific
    'LockStatus',
    // AccessControl
    'AccessControl', 'ACOwner', 'ACType',
    // Bytecode
    'BytecodeHash_OnChain', 'BytecodeHash_AddressBook', 'BytecodeHash_Match',
    'ImplBytecodeHash_OnChain'
  ];

  let csvOutput = csvHeaders.join(',') + '\n';

  // Track updates for addressBook
  const updates = {};

  // Track mismatches for summary
  const mismatches = [];

  // Process each contract
  for (const [name, info] of Object.entries(addressBook)) {
    // Skip contracts ending with "Impl" - they are just implementation references
    if (name.endsWith('Impl')) {
      continue;
    }

    if (!info.address) {
      continue;
    }

    console.log(`Processing ${name}...`);

    const contractAddress = info.address;
    const contractTypeName = ContractTypeNames[info.contractType] || 'Unknown';

    // Create contract interface with all functions we might need
    const contract = new ethers.Contract(
      contractAddress,
      [...ownerABI, ...implementationABI, ...accessControlABI, ...proxyAdminABI,
       ...proxyImplABI, ...effectiveImplABI, ...beaconABI, ...autoUpgradeABI, ...lockABI],
      provider
    );

    // ============ OWNER ============
    let ownerOnChain = '-';
    try {
      ownerOnChain = await contract.owner();
    } catch (error) {
      // Contract is not ownable or function doesn't exist
    }
    const ownerComparison = compareValues(ownerOnChain, info.owner, 'owner');

    // ============ PROXY ADMIN (from EIP1967 slot) ============
    let proxyAdminOnChain = '-';
    try {
      const adminSlotValue = await provider.getStorage(contractAddress, EIP1967_ADMIN_SLOT);
      const adminAddress = '0x' + adminSlotValue.substring(26);
      if (adminAddress !== '0x0000000000000000000000000000000000000000') {
        proxyAdminOnChain = ethers.getAddress(adminAddress);
      }
    } catch (error) {
      // Failed to get proxy admin
    }
    const proxyAdminComparison = compareValues(proxyAdminOnChain, info.proxyAdmin, 'proxyAdmin');

    // ============ PROXY ADMIN OWNER (if proxyAdmin is a contract) ============
    let proxyAdminIsContract = '-';
    let proxyAdminOwner = '-';
    let proxyAdminOwnerType = '-';
    if (proxyAdminOnChain !== '-') {
      proxyAdminIsContract = await isContract(provider, proxyAdminOnChain);
      if (proxyAdminIsContract) {
        proxyAdminOwnerType = 'contract';
        try {
          const paContract = new ethers.Contract(proxyAdminOnChain, ownerABI, provider);
          proxyAdminOwner = await paContract.owner();
        } catch {
          // Contract has no owner() function (e.g., MultiSig) - leave proxyAdminOwner empty
          proxyAdminOwner = '-';
        }
      } else {
        proxyAdminOwnerType = 'EOA';
        proxyAdminOwner = proxyAdminOnChain; // For EOA, the proxyAdmin IS the owner
      }
    }

    // ============ PROXY TYPE DETECTION ============
    let proxyType = '-';
    let beacon = '-';
    let beaconOwner = '-';
    let beaconDefaultVersion = '-';
    let autoUpgrade = '-';

    // Try to detect if it's a BeaconProxy by calling proxy__getBeacon()
    try {
      const beaconAddress = await contract.proxy__getBeacon();
      if (beaconAddress !== ethers.ZeroAddress) {
        proxyType = 'BeaconProxy';
        beacon = beaconAddress;

        // Get beacon owner
        try {
          const beaconContract = new ethers.Contract(beacon, ownerABI, provider);
          beaconOwner = await beaconContract.owner();
        } catch {}

        // Get beacon default version (storage slot 1)
        try {
          const versionSlotValue = await provider.getStorage(beacon, BEACON_DEFAULT_VERSION_SLOT);
          beaconDefaultVersion = ethers.toNumber(versionSlotValue);
        } catch {}

        // Get auto-upgrade status
        try {
          autoUpgrade = await contract.proxy__getAutoUpgrade();
        } catch {}
      }
    } catch (error) {
      // Not a BeaconProxy with this function
      // If we have a proxy admin from slot, it could be a TransparentUpgradeableProxy
      if (proxyAdminOnChain !== '-') {
        proxyType = 'EIP1967';
      }
    }

    // ============ IMPLEMENTATION ============
    let implementationOnChain = '-';

    if (proxyType === 'BeaconProxy' && beacon !== '-') {
      // For BeaconProxy, get the implementation from the beacon
      try {
        const beaconContract = new ethers.Contract(beacon, implementationABI, provider);
        implementationOnChain = await beaconContract.implementation();
      } catch (error) {
        // Failed to get implementation from beacon
      }
    } else if (proxyType === 'EIP1967') {
      // For EIP1967, read from storage slot
      try {
        const implSlotValue = await provider.getStorage(contractAddress, EIP1967_IMPLEMENTATION_SLOT);
        const implAddress = '0x' + implSlotValue.substring(26);
        if (implAddress !== '0x0000000000000000000000000000000000000000') {
          implementationOnChain = ethers.getAddress(implAddress);
        }
      } catch (error) {
        // Failed to get implementation
      }
    } else if (info.contractType === 1) {
      // If it's a Beacon contract, call implementation() method
      try {
        implementationOnChain = await contract.implementation();
      } catch (error) {
        // Failed to get implementation
      }

      // Also get beacon-specific info for Beacon contracts
      try {
        beaconOwner = await contract.owner();
      } catch {}
      try {
        const versionSlotValue = await provider.getStorage(contractAddress, BEACON_DEFAULT_VERSION_SLOT);
        beaconDefaultVersion = ethers.toNumber(versionSlotValue);
      } catch {}
    }

    const implementationComparison = compareValues(implementationOnChain, info.implementation, 'implementation');

    // ============ LOCK STATUS (for Lock contracts) ============
    let lockStatus = '-';
    if (name.includes('Lock') || info.contractName === 'Lock') {
      try {
        // We need to call isLocked() but it uses msg.sender context
        // So we just check the storage directly for _areAllAddressesUnlocked
        // Storage slot 0 for _areAllAddressesUnlocked (after Ownable storage)
        // Actually, let's try calling it - it will return based on msg.sender
        const isLocked = await contract.isLocked();
        lockStatus = isLocked ? 'LOCKED' : 'UNLOCKED';
      } catch {
        lockStatus = 'Error';
      }
    }

    // ============ ACCESS CONTROL ============
    let accessControl = '-';
    let acOwner = '-';
    let acType = '-';

    try {
      accessControl = await contract.getAccessControl();
      if (accessControl !== ethers.ZeroAddress) {
        // Create AccessControl contract interface
        const acContract = new ethers.Contract(accessControl, [...ownerABI, ...getTypeABI], provider);

        // Check owner of AccessControl
        try {
          acOwner = await acContract.owner();
        } catch (error) {
          // Failed to get owner of access control
        }

        // Get type of AccessControl
        try {
          const acTypeHash = (await acContract.getType()).toString();
          // Convert hash to human-readable name if known
          acType = AccessControlTypeNames[acTypeHash.toLowerCase()] || acTypeHash;
        } catch (error) {
          // Failed to get type of access control
        }
      }
    } catch (error) {
      // No getAccessControl function
    }

    // ============ BYTECODE HASHES ============
    const bytecodeHashOnChain = await getContractBytecodeHash(provider, contractAddress);
    const bytecodeComparison = compareValues(bytecodeHashOnChain, info.bytecodeHash, 'bytecodeHash');

    // Get bytecode hash of the implementation if this is a proxy
    let implBytecodeHashOnChain = '-';
    if (implementationOnChain !== '-') {
      implBytecodeHashOnChain = await getContractBytecodeHash(provider, implementationOnChain);
    }

    // ============ TRACK MISMATCHES ============
    if (ownerComparison.match === '✗') {
      mismatches.push({ contract: name, field: 'owner', onChain: ownerComparison.onChain, addressBook: ownerComparison.addressBook });
    }
    if (proxyAdminComparison.match === '✗') {
      mismatches.push({ contract: name, field: 'proxyAdmin', onChain: proxyAdminComparison.onChain, addressBook: proxyAdminComparison.addressBook });
    }
    if (implementationComparison.match === '✗') {
      mismatches.push({ contract: name, field: 'implementation', onChain: implementationComparison.onChain, addressBook: implementationComparison.addressBook });
    }
    if (bytecodeComparison.match === '✗') {
      mismatches.push({ contract: name, field: 'bytecodeHash', onChain: bytecodeComparison.onChain, addressBook: bytecodeComparison.addressBook });
    }

    // ============ PREPARE UPDATES FOR ADDRESSBOOK ============
    if (shouldUpdateAddressBook) {
      const contractUpdates = {};

      // Helper to check if value should be updated
      const shouldUpdate = (onChain, addressBookValue) => {
        if (onChain === '-' || onChain === undefined || onChain === null || onChain === '') return false;
        if (addressBookValue === undefined) return true;
        return normalizeHex(onChain) !== normalizeHex(addressBookValue);
      };

      // Core fields
      if (shouldUpdate(ownerOnChain, info.owner)) {
        contractUpdates.owner = ownerOnChain;
      }
      if (shouldUpdate(proxyAdminOnChain, info.proxyAdmin)) {
        contractUpdates.proxyAdmin = proxyAdminOnChain;
      }
      if (shouldUpdate(implementationOnChain, info.implementation)) {
        contractUpdates.implementation = implementationOnChain;
      }
      if (shouldUpdate(bytecodeHashOnChain, info.bytecodeHash)) {
        contractUpdates.bytecodeHash = bytecodeHashOnChain;
      }

      // Proxy type and details
      if (proxyType !== '-' && proxyType !== info.proxyType) {
        contractUpdates.proxyType = proxyType;
      }
      if (proxyAdminIsContract !== '-' && proxyAdminIsContract !== info.proxyAdminIsContract) {
        contractUpdates.proxyAdminIsContract = proxyAdminIsContract;
      }
      if (proxyAdminOwnerType !== '-' && proxyAdminOwnerType !== info.proxyAdminOwnerType) {
        contractUpdates.proxyAdminOwnerType = proxyAdminOwnerType;
      }
      if (shouldUpdate(proxyAdminOwner, info.proxyAdminOwner)) {
        contractUpdates.proxyAdminOwner = proxyAdminOwner;
      }

      // Beacon-related fields
      if (shouldUpdate(beacon, info.beacon)) {
        contractUpdates.beacon = beacon;
      }
      if (shouldUpdate(beaconOwner, info.beaconOwner)) {
        contractUpdates.beaconOwner = beaconOwner;
      }
      if (beaconDefaultVersion !== '-' && beaconDefaultVersion !== info.beaconDefaultVersion) {
        contractUpdates.beaconDefaultVersion = beaconDefaultVersion;
      }

      // Auto-upgrade status
      if (autoUpgrade !== '-' && autoUpgrade !== info.autoUpgrade) {
        contractUpdates.autoUpgrade = autoUpgrade;
      }

      // Lock status
      if (lockStatus !== '-' && lockStatus !== 'Error' && lockStatus !== info.lockStatus) {
        contractUpdates.lockStatus = lockStatus;
      }

      // AccessControl fields
      if (shouldUpdate(accessControl, info.accessControl)) {
        contractUpdates.accessControl = accessControl;
      }
      if (shouldUpdate(acOwner, info.accessControlOwner)) {
        contractUpdates.accessControlOwner = acOwner;
      }
      if (shouldUpdate(acType, info.accessControlType)) {
        contractUpdates.accessControlType = acType;
      }

      // Implementation bytecode hash
      if (shouldUpdate(implBytecodeHashOnChain, info.implBytecodeHash)) {
        contractUpdates.implBytecodeHash = implBytecodeHashOnChain;
      }

      if (Object.keys(contractUpdates).length > 0) {
        updates[name] = contractUpdates;
      }
    }

    // ============ BUILD CSV ROW ============
    const csvRow = [
      contractTypeName,
      name,
      contractAddress,
      // Ownership
      ownerOnChain,
      ownerComparison.addressBook,
      ownerComparison.match,
      // Proxy Info
      proxyType,
      proxyAdminOnChain,
      proxyAdminComparison.addressBook,
      proxyAdminComparison.match,
      proxyAdminIsContract,
      proxyAdminOwnerType,
      proxyAdminOwner,
      // Implementation
      implementationOnChain,
      implementationComparison.addressBook,
      implementationComparison.match,
      // Beacon specific
      beacon,
      beaconOwner,
      beaconDefaultVersion,
      // BeaconProxy specific
      autoUpgrade,
      // Lock specific
      lockStatus,
      // AccessControl
      accessControl,
      acOwner,
      acType,
      // Bytecode
      bytecodeHashOnChain,
      bytecodeComparison.addressBook,
      bytecodeComparison.match,
      implBytecodeHashOnChain
    ];

    csvOutput += csvRow.map(v => {
      // Escape commas in values
      const str = String(v);
      if (str.includes(',') || str.includes('"')) {
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    }).join(',') + '\n';
  }

  // ============ WRITE CSV ============
  const outputFile = `scripts/out/contracts_analysis_${addressBookFile.replace('.json', '').replace('addressBook.', '')}.csv`;
  fs.writeFileSync(outputFile, csvOutput);
  console.log(`\nAnalysis complete. Results saved to ${outputFile}`);

  // ============ PRINT MISMATCHES SUMMARY ============
  if (mismatches.length > 0) {
    console.log('\n' + '='.repeat(80));
    console.log('⚠️  MISMATCHES FOUND (AddressBook vs On-chain):');
    console.log('='.repeat(80));
    for (const m of mismatches) {
      console.log(`\n${m.contract}.${m.field}:`);
      console.log(`  AddressBook: ${m.addressBook}`);
      console.log(`  On-chain:    ${m.onChain}`);
    }
    console.log('\n' + '='.repeat(80));
  } else {
    console.log('\n✅ All addressBook values match on-chain state!');
  }

  // ============ UPDATE ADDRESSBOOK IF REQUESTED ============
  if (shouldUpdateAddressBook && Object.keys(updates).length > 0) {
    console.log('\n📝 Updating addressBook with on-chain values...');

    for (const [contractName, contractUpdates] of Object.entries(updates)) {
      for (const [field, value] of Object.entries(contractUpdates)) {
        console.log(`  ${contractName}.${field}: ${addressBook[contractName][field] || '-'} -> ${value}`);
        addressBook[contractName][field] = value;
      }
    }

    fs.writeFileSync(addressBookFile, JSON.stringify(addressBook, null, 2));
    console.log(`\n✅ AddressBook updated: ${addressBookFile}`);
  } else if (shouldUpdateAddressBook) {
    console.log('\n✅ No updates needed for addressBook');
  }
}

main().catch(error => {
  console.error('Error in main execution:', error);
  process.exit(1);
});
