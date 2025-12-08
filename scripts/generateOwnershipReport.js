const fs = require('fs');

// Get addressBook file from command line argument, default to mainnet
const addressBookFile = process.argv[2] || 'addressBook.mainnet.json';
const networkName = addressBookFile.replace('addressBook.', '').replace('.json', '');

console.log(`Generating ownership reports from: ${addressBookFile}`);

// Read addressBook
const addressBook = JSON.parse(fs.readFileSync(addressBookFile, 'utf8'));

// Contract type names
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

// Helper to escape CSV values
function csvEscape(value) {
  if (value === undefined || value === null) return '-';
  const str = String(value);
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str || '-';
}

// Helper to create CSV row
function csvRow(values) {
  return values.map(csvEscape).join(',');
}


// Determine ultimate controller for a contract
function getUltimateController(info) {
  // Priority: proxyAdminOwner > proxyAdmin (if EOA) > owner
  if (info.proxyAdminOwner && info.proxyAdminOwner !== '-') {
    return { address: info.proxyAdminOwner, via: 'ProxyAdmin Owner' };
  }
  if (info.proxyAdmin && info.proxyAdmin !== '-' && info.proxyAdminOwnerType === 'EOA') {
    return { address: info.proxyAdmin, via: 'ProxyAdmin (EOA)' };
  }
  if (info.proxyAdmin && info.proxyAdmin !== '-' && info.proxyAdminOwnerType === 'contract') {
    return { address: info.proxyAdmin, via: 'ProxyAdmin (Contract - no owner)' };
  }
  if (info.owner && info.owner !== '-') {
    return { address: info.owner, via: 'Direct Owner' };
  }
  return { address: '-', via: '-' };
}

// Filter out Impl contracts
const contracts = Object.entries(addressBook)
  .filter(([name, info]) => !name.endsWith('Impl') && info.address)
  .map(([name, info]) => ({ name, ...info }));

// ============================================================
// TABLE 1: Comprehensive Overview (Option 1)
// ============================================================
function generateComprehensiveTable() {
  const headers = [
    'Contract', 'Type', 'Address',
    'Owner', 'ProxyType', 'ProxyAdmin', 'ProxyAdminType', 'ProxyAdminOwner',
    'Implementation', 'Beacon', 'BeaconOwner', 'AutoUpgrade',
    'AccessControl', 'ACOwner', 'ACType',
    'LockStatus'
  ];

  const rows = contracts.map(c => [
    c.name,
    ContractTypeNames[c.contractType] || 'Unknown',
    c.address,
    c.owner || '-',
    c.proxyType || '-',
    c.proxyAdmin || '-',
    c.proxyAdminOwnerType || '-',
    c.proxyAdminOwner || '-',
    c.implementation || '-',
    c.beacon || '-',
    c.beaconOwner || '-',
    c.autoUpgrade !== undefined ? c.autoUpgrade : '-',
    c.accessControl || '-',
    c.accessControlOwner || '-',
    c.accessControlType || '-',
    c.lockStatus || '-'
  ]);

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// TABLE 2a: Ownership Overview (Option 2 - Sheet 1)
// ============================================================
function generateOwnershipTable() {
  const headers = [
    'Contract', 'Type', 'DirectOwner', 'ProxyAdmin', 'ProxyAdminType', 'ProxyAdminOwner', 'UltimateController', 'ControlPath'
  ];

  const rows = contracts.map(c => {
    const ultimate = getUltimateController(c);
    return [
      c.name,
      ContractTypeNames[c.contractType] || 'Unknown',
      c.owner || '-',
      c.proxyAdmin || '-',
      c.proxyAdminOwnerType || '-',
      c.proxyAdminOwner || '-',
      ultimate.address,
      ultimate.via
    ];
  });

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// TABLE 2b: Proxy & Implementation (Option 2 - Sheet 2)
// ============================================================
function generateProxyTable() {
  const headers = [
    'Contract', 'Type', 'ProxyType', 'ProxyAdmin', 'ProxyAdminOwner',
    'Implementation', 'ImplBytecodeHash',
    'Beacon', 'BeaconOwner', 'BeaconVersion', 'AutoUpgrade'
  ];

  const rows = contracts
    .filter(c => c.proxyType && c.proxyType !== '-') // Only proxy contracts
    .map(c => [
      c.name,
      ContractTypeNames[c.contractType] || 'Unknown',
      c.proxyType || '-',
      c.proxyAdmin || '-',
      c.proxyAdminOwner || '-',
      c.implementation || '-',
      c.implBytecodeHash || '-',
      c.beacon || '-',
      c.beaconOwner || '-',
      c.beaconDefaultVersion !== undefined ? c.beaconDefaultVersion : '-',
      c.autoUpgrade !== undefined ? c.autoUpgrade : '-'
    ]);

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// TABLE 2c: AccessControl (Option 2 - Sheet 3)
// ============================================================
function generateAccessControlTable() {
  const headers = [
    'Contract', 'Type', 'AccessControl', 'ACOwner', 'ACType'
  ];

  const rows = contracts
    .filter(c => c.accessControl && c.accessControl !== '-') // Only contracts with AC
    .map(c => [
      c.name,
      ContractTypeNames[c.contractType] || 'Unknown',
      c.accessControl || '-',
      c.accessControlOwner || '-',
      c.accessControlType || '-'
    ]);

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// TABLE 3: By Controller (Option 3) - All control relationships
// ============================================================
function generateByControllerTable() {
  const byController = {};

  const addToController = (address, contractName, contractType, via) => {
    if (!address || address === '-') return;
    if (!byController[address]) {
      byController[address] = { address, contracts: [] };
    }
    // Avoid duplicates
    const key = `${contractName}|${via}`;
    if (!byController[address].contracts.find(c => `${c.name}|${c.via}` === key)) {
      byController[address].contracts.push({
        name: contractName,
        type: contractType,
        via: via
      });
    }
  };

  contracts.forEach(c => {
    const contractType = ContractTypeNames[c.contractType] || 'Unknown';

    // Track direct owner (contract logic control)
    if (c.owner && c.owner !== '-') {
      addToController(c.owner, c.name, contractType, 'Contract Owner');
    }

    // Track proxy admin (upgrade control)
    if (c.proxyAdmin && c.proxyAdmin !== '-') {
      if (c.proxyAdminOwnerType === 'EOA') {
        addToController(c.proxyAdmin, c.name, contractType, 'ProxyAdmin (EOA)');
      } else if (c.proxyAdminOwnerType === 'contract') {
        if (c.proxyAdminOwner && c.proxyAdminOwner !== '-') {
          addToController(c.proxyAdminOwner, c.name, contractType, 'ProxyAdmin Owner');
        } else {
          addToController(c.proxyAdmin, c.name, contractType, 'ProxyAdmin (Contract)');
        }
      }
    }

    // Track beacon ownership
    if (c.beaconOwner && c.beaconOwner !== '-') {
      addToController(c.beaconOwner, c.name, 'Beacon', 'Beacon Owner');
    }

    // Track AC ownership
    if (c.accessControlOwner && c.accessControlOwner !== '-') {
      addToController(c.accessControlOwner, c.name, 'AccessControl', 'AC Owner');
    }
  });

  // Create flat table
  const headers = ['Controller', 'Contract', 'ContractType', 'ControlVia', 'TotalControlled'];

  const rows = [];
  Object.values(byController)
    .sort((a, b) => b.contracts.length - a.contracts.length) // Sort by number of contracts controlled
    .forEach(controller => {
      controller.contracts.forEach((contract, idx) => {
        rows.push([
          controller.address,
          contract.name,
          contract.type,
          contract.via,
          idx === 0 ? controller.contracts.length : '' // Only show count on first row
        ]);
      });
    });

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// TABLE 4: Summary by Controller (Condensed view)
// ============================================================
function generateControllerSummary() {
  const initRoles = () => ({
    'Contract Owner': [],
    'ProxyAdmin (EOA)': [],
    'ProxyAdmin Owner': [],
    'ProxyAdmin (Contract)': [],
    'Beacon Owner': [],
    'AC Owner': []
  });

  // Group contracts by controller
  const byController = {};

  const addToController = (address, role, contractName) => {
    if (!address || address === '-') return;
    if (!byController[address]) {
      byController[address] = { address, roles: initRoles() };
    }
    if (!byController[address].roles[role].includes(contractName)) {
      byController[address].roles[role].push(contractName);
    }
  };

  contracts.forEach(c => {
    // Track direct owner (contract logic control)
    if (c.owner && c.owner !== '-') {
      addToController(c.owner, 'Contract Owner', c.name);
    }

    // Track proxy admin (upgrade control)
    if (c.proxyAdmin && c.proxyAdmin !== '-') {
      if (c.proxyAdminOwnerType === 'EOA') {
        addToController(c.proxyAdmin, 'ProxyAdmin (EOA)', c.name);
      } else if (c.proxyAdminOwnerType === 'contract') {
        if (c.proxyAdminOwner && c.proxyAdminOwner !== '-') {
          addToController(c.proxyAdminOwner, 'ProxyAdmin Owner', c.name);
        } else {
          addToController(c.proxyAdmin, 'ProxyAdmin (Contract)', c.name);
        }
      }
    }

    // Track beacon ownership (use contract name for clarity)
    if (c.beaconOwner && c.beaconOwner !== '-') {
      addToController(c.beaconOwner, 'Beacon Owner', c.name);
    }

    // Track AC ownership
    if (c.accessControlOwner && c.accessControlOwner !== '-') {
      addToController(c.accessControlOwner, 'AC Owner', c.name);
    }
  });

  const headers = ['Controller', 'TotalRoles', 'ContractOwner', 'ProxyAdmin_EOA', 'ProxyAdminOwner', 'ProxyAdmin_Contract', 'BeaconOwner', 'ACOwner'];

  const rows = Object.values(byController)
    .map(c => {
      const totalRoles = Object.values(c.roles).flat().length;
      return [
        c.address,
        totalRoles,
        c.roles['Contract Owner'].length > 0 ? c.roles['Contract Owner'].length + ': ' + c.roles['Contract Owner'].join(', ') : '-',
        c.roles['ProxyAdmin (EOA)'].length > 0 ? c.roles['ProxyAdmin (EOA)'].length + ': ' + c.roles['ProxyAdmin (EOA)'].join(', ') : '-',
        c.roles['ProxyAdmin Owner'].length > 0 ? c.roles['ProxyAdmin Owner'].length + ': ' + c.roles['ProxyAdmin Owner'].join(', ') : '-',
        c.roles['ProxyAdmin (Contract)'].length > 0 ? c.roles['ProxyAdmin (Contract)'].length + ': ' + c.roles['ProxyAdmin (Contract)'].join(', ') : '-',
        c.roles['Beacon Owner'].length > 0 ? c.roles['Beacon Owner'].length + ': ' + c.roles['Beacon Owner'].join(', ') : '-',
        c.roles['AC Owner'].length > 0 ? c.roles['AC Owner'].length + ': ' + c.roles['AC Owner'].join(', ') : '-'
      ];
    })
    .sort((a, b) => b[1] - a[1]); // Sort by total roles

  return [headers, ...rows].map(csvRow).join('\n');
}

// ============================================================
// Generate all tables
// ============================================================
const outputDir = 'scripts/out';

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const tables = [
  { name: '1_comprehensive', generator: generateComprehensiveTable, description: 'Comprehensive Overview' },
  { name: '2a_ownership', generator: generateOwnershipTable, description: 'Ownership Overview' },
  { name: '2b_proxy', generator: generateProxyTable, description: 'Proxy & Implementation' },
  { name: '2c_accesscontrol', generator: generateAccessControlTable, description: 'AccessControl' },
  { name: '3_by_controller', generator: generateByControllerTable, description: 'By Controller (Detailed)' },
  { name: '4_controller_summary', generator: generateControllerSummary, description: 'Controller Summary' }
];

console.log('\nGenerating tables...\n');

tables.forEach(table => {
  const filename = `${outputDir}/ownership_${table.name}_${networkName}.csv`;
  const content = table.generator();
  fs.writeFileSync(filename, content);
  console.log(`✅ ${table.description}: ${filename}`);
});

console.log('\n🎉 All reports generated successfully!');
