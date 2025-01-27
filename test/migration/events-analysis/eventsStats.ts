import * as fs from 'fs';
import * as path from 'path';

interface Event {
  address: string;
  blockHash: string;
  blockNumber: number;
  logIndex: number;
  removed: boolean;
  topics: string[];
  transactionHash: string;
  transactionIndex: number;
}

interface AddressBookEntry {
  contractName: string;
  address: string;
  [key: string]: any;
}

interface AddressBook {
  [key: string]: AddressBookEntry;
}

function loadEvents(): Event[] {
  const eventsPath = path.join(__dirname, 'events.json');
  const eventsData = fs.readFileSync(eventsPath, 'utf-8');
  return JSON.parse(eventsData);
}

function loadAddressBook(): AddressBook {
  const addressBookPath = path.join(__dirname, 'addressBook.json');
  const addressBookData = fs.readFileSync(addressBookPath, 'utf-8');
  return JSON.parse(addressBookData);
}

function isSystemAddress(address: string): boolean {
  // Check if address starts with many zeros (0x0000000000000000000000000)
  return /^0x0{23,}/.test(address);
}

function getContractName(address: string, addressBook: AddressBook): string {
  const normalizedAddress = address.toLowerCase();
  for (const entry of Object.values(addressBook)) {
    if (entry.address.toLowerCase() === normalizedAddress) {
      return entry.contractName;
    }
  }
  return 'Unknown Contract';
}

function getDistinctAddresses(events: Event[], addressBook: AddressBook): Array<{ address: string; contractName: string }> {
  // Filter out system addresses and create a map of unique addresses
  const addressMap: { [key: string]: boolean } = {};
  events
    .filter(event => !isSystemAddress(event.address))
    .forEach(event => {
      addressMap[event.address] = true;
    });

  // Convert to array, sort, and add contract names
  return Object.keys(addressMap)
    .sort()
    .map(address => ({
      address,
      contractName: getContractName(address, addressBook)
    }));
}

function groupAddressesByContract(addresses: Array<{ address: string; contractName: string }>): { [key: string]: string[] } {
  const groups: { [key: string]: string[] } = {};

  addresses.forEach(({ address, contractName }) => {
    if (!groups[contractName]) {
      groups[contractName] = [];
    }
    groups[contractName].push(address);
  });

  return groups;
}

function main() {
  try {
    const events = loadEvents();
    const addressBook = loadAddressBook();
    const distinctAddresses = getDistinctAddresses(events, addressBook);
    const groupedAddresses = groupAddressesByContract(distinctAddresses);

    // Sort contract names but put "Unknown Contract" at the end
    const sortedContractNames = Object.keys(groupedAddresses)
      .filter(name => name !== 'Unknown Contract')
      .sort();

    if (groupedAddresses['Unknown Contract']) {
      sortedContractNames.push('Unknown Contract');
    }

    // Display grouped addresses
    sortedContractNames.forEach(contractName => {
      console.log(`${contractName}:`);
      groupedAddresses[contractName].forEach(address => {
        console.log(`  ${address}`);
      });
      console.log(''); // Empty line for better readability
    });

    console.log(`Total distinct addresses: ${distinctAddresses.length}`);
  } catch (error) {
    console.error('Error processing events:', error);
  }
}

main();
