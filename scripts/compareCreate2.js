const fs = require('fs');

function parseCSV(content) {
  const lines = content.split('\n');
  const headers = lines[0].split(',');
  const result = [];

  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = lines[i].split(',');
    const entry = {};
    headers.forEach((header, index) => {
      entry[header] = values[index];
    });
    result.push(entry);
  }

  return result;
}

function main() {
  // Read create2.csv
  const create2Content = fs.readFileSync('create2.csv', 'utf8');
  const create2Data = parseCSV(create2Content);

  // Read addressBook.json
  const addressBook = JSON.parse(fs.readFileSync('addressBook.json', 'utf8'));

  // Create maps for easier comparison
  const create2Map = new Map();
  const addressBookMap = new Map();

  // Populate create2Map
  for (const entry of create2Data) {
    create2Map.set(entry.ContractName, {
      address: entry.Address.toLowerCase(),
      presalt: entry.PreSalt
    });
  }

  // Populate addressBookMap
  for (const [name, info] of Object.entries(addressBook)) {
    if (info.address) {
      addressBookMap.set(name, {
        address: info.address.toLowerCase(),
        presalt: info.lensCreate2PreSalt
      });
    }
  }

  // Compare addresses
  console.log('\nAddress Comparisons:');
  console.log('===================');
  for (const [name, create2Info] of create2Map) {
    const addressBookInfo = addressBookMap.get(name);
    if (!addressBookInfo) {
      console.log(`❌ ${name} exists in create2.csv but not in addressBook.json`);
      continue;
    }

    if (create2Info.address !== addressBookInfo.address) {
      console.log(`❌ ${name} address mismatch:`);
      console.log(`  create2.csv: ${create2Info.address}`);
      console.log(`  addressBook.json: ${addressBookInfo.address}`);
    } else {
      console.log(`✅ ${name} addresses match: ${create2Info.address}`);
    }
  }

  // Check for entries in addressBook that don't exist in create2
  for (const [name, info] of addressBookMap) {
    if (!create2Map.has(name)) {
      console.log(`⚠️ ${name} exists in addressBook.json but not in create2.csv`);
    }
  }

  // Compare presalts
  console.log('\nPresalt Comparisons:');
  console.log('===================');
  for (const [name, create2Info] of create2Map) {
    const addressBookInfo = addressBookMap.get(name);
    if (!addressBookInfo) continue;

    if (create2Info.presalt !== addressBookInfo.presalt) {
      console.log(`❌ ${name} presalt mismatch:`);
      console.log(`  create2.csv: ${create2Info.presalt}`);
      console.log(`  addressBook.json: ${addressBookInfo.presalt}`);
    } else {
      console.log(`✅ ${name} presalts match: ${create2Info.presalt}`);
    }
  }
}

main();
