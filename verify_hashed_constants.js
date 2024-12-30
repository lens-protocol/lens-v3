const fs = require('fs');
const path = require('path');
const { keccak256, toUtf8Bytes } = require('ethers'); // Import directly in ethers v6.x
const process = require('process');

// Compute keccak256 using ethers.js
function computeKeccak256(input) {
  const hash = keccak256(toUtf8Bytes(input)); // UTF-8 encoding and hash
  return hash; // Already prefixed with '0x'
}

// Recursively find all .sol files in a directory
function getSolFiles(dir, fileList = []) {
  fs.readdirSync(dir).forEach((file) => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getSolFiles(filePath, fileList);
    } else if (file.endsWith('.sol')) {
      fileList.push(filePath);
    }
  });
  return fileList;
}

// Extract and validate keccak256 hashes
function extractAndValidateKeccak(folderPath) {
  let someUnmatch = false;
  const files = getSolFiles(folderPath);

  const annotationRegex = /\/\/\/ @custom:keccak\s+([a-zA-Z0-9_.]+)/;
  const constantRegex = /(uint256|bytes32)\s+constant\s+([A-Z_]+)\s*=\s*(0x[a-fA-F0-9]+);/;

  files.forEach((filePath) => {
    let hasSomeHashToCompute = false;
    const lines = fs.readFileSync(filePath, 'utf-8').split('\n');

    let hashToCompute = null;

    lines.forEach((line) => {
      const annotationMatch = annotationRegex.exec(line);
      if (annotationMatch) {
        hashToCompute = annotationMatch[1].trim(); // Ensure no extra spaces
        return;
      }

      const constantMatch = constantRegex.exec(line);
      if (constantMatch && hashToCompute) {
        const [_, type, constantName, value] = constantMatch;

        if (!hasSomeHashToCompute) {
          console.log(`\n\n\n - - - - - At file: ${filePath}\n`);
          hasSomeHashToCompute = true;
        }

        // Compute keccak256 hash of the annotation
        const computedHash = computeKeccak256(hashToCompute);

        if (computedHash === value) {
          console.log(`• Hash to compute:   "${hashToCompute}"`);
          console.log(`• Constant name:     ${constantName}:`);
          console.log(`• Computed:          ${computedHash}`);
          console.log(`• Extracted:         ${value}`);
          console.log(`⦿ Match status:      Correct ✅`);
        } else {
          someUnmatch = true;
          console.error(`• Hash to compute:   "${hashToCompute}"`);
          console.error(`• Constant name:     ${constantName}:`);
          console.error(`• Computed:          ${computedHash}`);
          console.error(`• Extracted:         ${value}`);
          console.error(`⦿ Match status:      Incorrect ❌`);
        }

        console.log(``);
        hashToCompute = null;
      }
    });
  });

  return someUnmatch;
}

const folderPath = 'contracts'; // Update to the path of your contracts folder
let someUnmatch = extractAndValidateKeccak(folderPath);
if (someUnmatch) {
  process.exit(1);
} else {
  process.exit(0);
}
