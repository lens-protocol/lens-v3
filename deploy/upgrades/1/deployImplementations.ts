import {
  ContractType,
  ContractInfo,
  deployLensContract,
  loadContractAddressFromAddressBook,
} from '../../lensUtils';

async function deploy() {
  const contractsToDeploy: ContractInfo[] = [
    // Beacon Implementations (fixes)
    {
      name: 'FeedImpl',
      contractName: 'MigrationFeed',
      contractType: ContractType.Implementation,
      constructorArguments: [],
    },
    {
      name: 'NamespaceImpl',
      contractName: 'MigrationNamespace',
      contractType: ContractType.Implementation,
      constructorArguments: [],
    },
    // Beacon Implementations (final versions)
    {
      name: 'AccountImpl',
      contractName: 'Account',
      contractType: ContractType.Implementation,
      constructorArguments: [],
    },
    {
      name: 'AppImpl',
      contractName: 'App',
      contractType: ContractType.Implementation,
      constructorArguments: [],
    },
    {
      name: 'GraphImpl',
      contractName: 'Graph',
      contractType: ContractType.Implementation,
      constructorArguments: [],
    },
    // TransparentUpgradeableProxy Implementations (Factories)
    {
      name: 'AccessControlFactoryImpl',
      contractName: 'AccessControlFactory',
      contractType: ContractType.Factory,
      constructorArguments: [loadContractAddressFromAddressBook('AccessControlLock')],
    },
    {
      name: 'AccountFactoryImpl',
      contractName: 'AccountFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AccountBeacon'),
        loadContractAddressFromAddressBook('AccountLock'),
      ],
    },
    {
      name: 'AppFactoryImpl',
      contractName: 'AppFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AppBeacon'),
        loadContractAddressFromAddressBook('AppLock'),
      ],
    },
    {
      name: 'FeedFactoryImpl',
      contractName: 'FeedFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('FeedBeacon'),
        loadContractAddressFromAddressBook('FeedLock'),
      ],
    },
    {
      name: 'GraphFactoryImpl',
      contractName: 'GraphFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GraphBeacon'),
        loadContractAddressFromAddressBook('GraphLock'),
      ],
    },
    {
      name: 'NamespaceFactoryImpl',
      contractName: 'NamespaceFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('NamespaceBeacon'),
        loadContractAddressFromAddressBook('NamespaceLock'),
      ],
    },
  ];

  const deployedContracts: Record<string, ContractInfo> = {};

  for (let contractToDeploy of contractsToDeploy) {
    let name = contractToDeploy.name ?? contractToDeploy.contractName;
    deployedContracts[name] = await deployLensContract(contractToDeploy, true);

    console.log(
      '\x1b[33m\n------------------------------------------------------------------------------------------------\x1b[0m'
    );
    console.log(
      `\x1b[33m${name} deployed at ${await deployedContracts[name]
        .address} with the following constructor arguments:\x1b[0m`
    );
    console.log(
      '\x1b[33m\n------------------------------------------------------------------------------------------------\x1b[0m'
    );
    console.table(deployedContracts[name].constructorArguments);
    console.log('\n');
  }
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
