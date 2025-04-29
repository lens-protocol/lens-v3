const fs = require('fs');
const { ethers } = require('ethers');

// ABI for the getAccessControl function
const accessControlABI = ['function getAccessControl() view returns (address)'];
// ABI for the getType function
const getTypeABI = ['function getType() view returns (bytes32)', 'function owner() view returns (address)'];

// Hardcoded types
const PERMISSIONLESS_TYPE = '0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae';
const OWNER_ADMIN_ONLY_CONTRACT_TYPE = '0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb';

// Function to read addresses from a CSV file
function readAddressesFromCSV(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    // Split by newline, filter out empty lines, and trim whitespace
    return data.split('\n').map(line => line.trim()).filter(line => line.length > 0 && line.startsWith('0x'));
  } catch (error) {
    console.error(`Error reading file ${filePath}:`, error.message);
    return [];
  }
}

async function main() {
  const appAddresses = require('../apps.json').map((app) => app.app_address);
  console.log(`Loaded ${appAddresses.length} apps`);

  if (appAddresses.length === 0) {
    console.log('No valid addresses found in apps.json');
    return;
  }

  // Setup provider (uses default provider since user specified no RPC URL needed)
  // If you need a specific RPC, uncomment and set the URL below:
  // const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL_HERE');
  const provider = new ethers.JsonRpcProvider('https://api.lens.matterhosted.dev');
//   const provider = new ethers.JsonRpcProvider('http://localhost:8011');

  console.log('App Address,Access Control Address,AC Type,AC Owner');

  for (const appAddress of appAddresses) {
    try {
      if (!ethers.isAddress(appAddress)) {
        console.log(`${appAddress},Invalid Address,-`);
        continue;
      }

      const contract = new ethers.Contract(appAddress, accessControlABI, provider);
      const accessControlAddress = await contract.getAccessControl();

      let acType = '-'; // Default type
      let acOwner = '-'; // Default owner
      if (accessControlAddress === ethers.ZeroAddress) {
          console.log(`${appAddress},ZeroAddress,-`);
      } else if (!ethers.isAddress(accessControlAddress)) {
          console.log(`${appAddress},Invalid AC Address,-`);
      }
      else {
          // Get the type of the Access Control contract
          try {
            const acContract = new ethers.Contract(accessControlAddress, getTypeABI, provider);
            const fetchedType = await acContract.getType();
            // let acOwner = '-';

            if (fetchedType === PERMISSIONLESS_TYPE) {
                acType = 'Permissionless';
            } else if (fetchedType === OWNER_ADMIN_ONLY_CONTRACT_TYPE) {
                acType = 'OwnerAdminOnly';
                acOwner = await acContract.owner();
            } else {
                acType = fetchedType; // Show the raw bytes32 if not permissionless
            }
          } catch (typeError) {
              if (typeError.code === 'CALL_EXCEPTION') {
                  acType = 'No getType function or reverted';
              } else {
                  acType = 'Error fetching type';
              }
          }

          console.log(`${appAddress},${accessControlAddress},${acType},${acOwner}`);
      }

    } catch (error) {
      // Handle cases where the function doesn't exist or other errors occur
      // error.code === 'CALL_EXCEPTION' is common if the function doesn't exist
      let errorMessage = 'Error';
      if (error.code === 'CALL_EXCEPTION') {
          errorMessage = 'No getAccessControl function or reverted';
      } else if (error.message) {
          // Truncate long error messages
          errorMessage = error.message.substring(0, 100) + '...';
      }
       console.log(`${appAddress}: ${errorMessage}`);
    }
  }
}

main().catch(error => {
  console.error('Error in main execution:', error);
});
