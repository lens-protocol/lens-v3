import fs from 'fs';
import path from 'path';

const artifactsFolderPath = 'artifacts-zk/contracts';
const abisFolderPath = 'abis';

function extractAbiFromJson(jsonPath: string) {
  try {
    const jsonContent = fs.readFileSync(jsonPath, 'utf-8');
    const contractData = JSON.parse(jsonContent);
    const abi = contractData.abi;
    const abiFileName = path.basename(jsonPath);
    const abiFilePath = path.join(abisFolderPath, abiFileName);
    fs.writeFileSync(abiFilePath, JSON.stringify(abi, null, 2));
    console.log(`Extracted ABI from ${jsonPath} to ${abiFilePath}`);
  } catch (error) {
    console.error(`Error extracting ABI from ${jsonPath}: ${error}`);
  }
}

function extractAbisFromFolder(folderPath: string) {
  const files = fs.readdirSync(folderPath);
  files.forEach((file) => {
    const filePath = path.join(folderPath, file);
    const stats = fs.statSync(filePath);
    if (stats.isDirectory()) {
      extractAbisFromFolder(filePath);
    } else if (path.extname(file) === '.json' && !file.endsWith('.dbg.json')) {
      extractAbiFromJson(filePath);
    }
  });
}

if (!fs.existsSync(abisFolderPath)) {
  fs.mkdirSync(abisFolderPath);
}

extractAbisFromFolder(artifactsFolderPath);
