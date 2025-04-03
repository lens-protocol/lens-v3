const fs = require('fs');
const { ethers } = require('ethers');
const crypto = require('crypto');

// Constants for storage slots
const EIP1967_ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
const EIP1967_IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
const BEACON_SLOT = '0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50';

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

// ABI for common functions
const ownerABI = ['function owner() view returns (address)'];
const implementationABI = ['function implementation() view returns (address)'];
const accessControlABI = ['function getAccessControl() view returns (address)'];
const getTypeABI = ['function getType() view returns (bytes32)'];
const proxyAdminABI = ['function proxy__getProxyAdmin() view returns (address)'];
const proxyImplABI = ['function proxy__getImplementation() view returns (address)'];
const effectiveImplABI = ['function proxy__getEffectiveImplementation() view returns (address)'];
const beaconABI = ['function proxy__getBeacon() view returns (address)'];

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

  return hash.toString('hex');
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

async function main() {
  // Read addressBook.json
  const addressBook = JSON.parse(fs.readFileSync('addressBook.json', 'utf8'));

  // Setup provider with the Lens RPC URL
  const provider = new ethers.JsonRpcProvider('https://api.lens.matterhosted.dev');

  // Initialize CSV output with simplified columns, removing boolean columns and moving ContractType first
  let csvOutput = 'ContractType,ContractName,Address,Owner,' +
    'ProxyType,ProxyAdmin,Implementation,Beacon,' +
    'AddressBook_Implementation,ImplementationMatches,' +
    'AccessControl,ACOwner,ACType,' +
    'BytecodeHash,ImplementationBytecodeHash\n';

  // Process each contract
  for (const [name, info] of Object.entries(addressBook)) {
    // Skip contracts ending with "Impl"
    if (name.endsWith('Impl')) {
      continue;
    }

    if (!info.address) {
      continue;
    }

    console.log(`Processing ${name}...`);

    const contractAddress = info.address;
    const contractTypeName = ContractTypeNames[info.contractType] || 'Unknown';

    // Create default contract interface with all functions we might need
    const contract = new ethers.Contract(
      contractAddress,
      [...ownerABI, ...implementationABI, ...accessControlABI, ...proxyAdminABI, ...proxyImplABI, ...effectiveImplABI, ...beaconABI],
      provider
    );

    // Check if the contract is ownable
    let owner = '-';
    try {
      owner = await contract.owner();
    } catch (error) {
      // Contract is not ownable or function doesn't exist
    }

    // Check EIP1967 proxy admin by reading from storage
    let proxyAdmin = '-';
    try {
      const adminSlotValue = await provider.getStorage(contractAddress, EIP1967_ADMIN_SLOT);
      const adminAddress = '0x' + adminSlotValue.substring(26);
      if (adminAddress !== '0x0000000000000000000000000000000000000000') {
        proxyAdmin = ethers.getAddress(adminAddress);
      }
    } catch (error) {
      // Failed to get proxy admin
    }

    // Determine if this is a proxy and which type
    let proxyType = '-';
    let beacon = '-';

    // Try to detect if it's a BeaconProxy by calling proxy__getBeacon()
    try {
      const beaconAddress = await contract.proxy__getBeacon();
      if (beaconAddress !== ethers.ZeroAddress) {
        proxyType = 'BeaconProxy';
        beacon = beaconAddress;
      }
    } catch (error) {
      // Not a BeaconProxy with this function

      // If we have a proxy admin from slot, it could be a TransparentUpgradeableProxy
      if (proxyAdmin !== '-') {
        proxyType = 'EIP1967';
      }
    }

    // Get implementation
    let implementation = '-';

    if (proxyType === 'BeaconProxy' && beacon !== '-') {
      // For BeaconProxy, get the implementation from the beacon
      try {
        const beaconContract = new ethers.Contract(beacon, implementationABI, provider);
        implementation = await beaconContract.implementation();
      } catch (error) {
        // Failed to get implementation from beacon
      }
    } else if (proxyType === 'EIP1967') {
      // For EIP1967, read from storage slot
      try {
        const implSlotValue = await provider.getStorage(contractAddress, EIP1967_IMPLEMENTATION_SLOT);
        const implAddress = '0x' + implSlotValue.substring(26);
        if (implAddress !== '0x0000000000000000000000000000000000000000') {
          implementation = ethers.getAddress(implAddress);
        }
      } catch (error) {
        // Failed to get implementation
      }
    } else if (info.contractType === 1) {
      // If it's a Beacon contract, call implementation() method
      try {
        implementation = await contract.implementation();
      } catch (error) {
        // Failed to get implementation
      }
    }

    // Check if implementation matches what's in addressBook
    let addressBookImplementation = info.implementation || '-';
    let implementationMatches = '-';

    if (addressBookImplementation !== '-' && implementation !== '-') {
      implementationMatches = (implementation.toLowerCase() === addressBookImplementation.toLowerCase()).toString();
    }

    // Check for AccessControl
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
          acType = (await acContract.getType()).toString();
        } catch (error) {
          // Failed to get type of access control
        }
      }
    } catch (error) {
      // No getAccessControl function
    }

    // Get bytecode hash of the contract itself
    const bytecodeHash = await getContractBytecodeHash(provider, contractAddress);

    // Get bytecode hash of the implementation if this is a proxy
    let implementationBytecodeHash = '-';
    if (implementation !== '-') {
      implementationBytecodeHash = await getContractBytecodeHash(provider, implementation);
    }

    // Add to CSV with ContractType as first column
    csvOutput += `${contractTypeName},${name},${contractAddress},${owner},` +
      `${proxyType},${proxyAdmin},${implementation},${beacon},` +
      `${addressBookImplementation},${implementationMatches},` +
      `${accessControl},${acOwner},${acType},` +
      `${bytecodeHash},${implementationBytecodeHash}\n`;
  }

  // Write CSV to file
  fs.writeFileSync('contracts_analysis.csv', csvOutput);
  console.log('Analysis complete. Results saved to contracts_analysis.csv');
}

main().catch(error => {
  console.error('Error in main execution:', error);
});
