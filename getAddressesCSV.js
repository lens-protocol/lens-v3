const fs = require('fs');

function getAddressesCSV() {
  // Load address book JSON
  const addressBook = JSON.parse(fs.readFileSync('./addressBook.testnet.json', 'utf8'));

  // Get all contract keys
  const contracts = Object.keys(addressBook);

  // Build CSV string with header
  let csv = 'Contract,Address\n';

  // Add each contract and address
  contracts.forEach(contract => {
    const address = addressBook[contract].address;
    csv += `${contract},${address}\n`;
  });

  return csv;
}

// Write to file
const csv = getAddressesCSV();
fs.writeFileSync('addresses.csv', csv);
