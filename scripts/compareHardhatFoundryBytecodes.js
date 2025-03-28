const fs = require("fs");
const path = require("path");

// ANSI color codes
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";

/**
 * Recursively get all files in a directory
 * @param {string} dir - Directory to scan
 * @param {Array<string>} fileList - Array to store results
 * @returns {Array<string>} List of file paths
 */
function getAllFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getAllFiles(filePath, fileList);
    } else {
      // Only include JSON files and exclude debug files
      if (filePath.endsWith('.json') && !filePath.endsWith('.dbg.json')) {
        fileList.push(filePath);
      }
    }
  });

  return fileList;
}

/**
 * Get filename without path
 * @param {string} filePath - Full file path
 * @returns {string} Filename without path
 */
function getFilenameWithoutPath(filePath) {
  return path.basename(filePath);
}

/**
 * Check if a file has valid bytecode
 * @param {Object} data - JSON data from file
 * @returns {boolean} True if valid bytecode exists
 */
function hasValidBytecode(data) {
  // For artifacts-zk files
  if (data.bytecode && typeof data.bytecode === 'string' && data.bytecode !== '0x' && data.bytecode.length > 2) {
    return true;
  }

  // For zkout files
  if (data.bytecode && data.bytecode.object && typeof data.bytecode.object === 'string' &&
      data.bytecode.object !== '0x' && data.bytecode.object.length > 0) {
    return true;
  }

  return false;
}

/**
 * Compare bytecodes from two matching files
 * @param {string} artifactsFilePath - Path to file in artifacts-zk
 * @param {string} zkoutFilePath - Path to file in zkout
 * @returns {boolean} True if bytecodes match
 */
function compareBytecodes(artifactsFilePath, zkoutFilePath) {
  try {
    // Read files
    const artifactsData = JSON.parse(fs.readFileSync(artifactsFilePath, "utf8"));
    const zkoutData = JSON.parse(fs.readFileSync(zkoutFilePath, "utf8"));

    // Check if both files have valid bytecode
    if (!hasValidBytecode(artifactsData) || !hasValidBytecode(zkoutData)) {
      return null; // Skip this comparison
    }

    // Extract bytecode from artifacts-zk (remove 0x prefix if present)
    const artifactsBytecode = artifactsData.bytecode.startsWith("0x")
      ? artifactsData.bytecode.slice(2)
      : artifactsData.bytecode;

    // Extract bytecode from zkout
    const zkoutBytecode = zkoutData.bytecode.object;

    // Compare the bytecodes
    return artifactsBytecode === zkoutBytecode;
  } catch (error) {
    console.error(`Error comparing ${artifactsFilePath} with ${zkoutFilePath}:`, error.message);
    return null;
  }
}

function compareAllBytecodes() {
  // Directories to scan
  const artifactsDir = "artifacts-zk";
  const zkoutDir = "zkout";

  // Get all JSON files (excluding debug files)
  const artifactsFiles = getAllFiles(artifactsDir);
  const zkoutFiles = getAllFiles(zkoutDir);

  // Create maps of filenames to full paths
  const artifactsMap = new Map();
  const zkoutMap = new Map();

  artifactsFiles.forEach(file => {
    artifactsMap.set(getFilenameWithoutPath(file), file);
  });

  zkoutFiles.forEach(file => {
    zkoutMap.set(getFilenameWithoutPath(file), file);
  });

  // Find matching files
  const matchingFilenames = [...artifactsMap.keys()].filter(filename => zkoutMap.has(filename));

  // Compare bytecodes for matching files
  console.log("\nBytecode Comparison Results:");
  console.log("----------------------------------------");

  let matchCount = 0;
  let mismatchCount = 0;
  let skippedCount = 0;

  matchingFilenames.forEach(filename => {
    const artifactsPath = artifactsMap.get(filename);
    const zkoutPath = zkoutMap.get(filename);

    const result = compareBytecodes(artifactsPath, zkoutPath);

    if (result === true) {
      console.log(`${GREEN}${filename}: MATCH${RESET}`);
      matchCount++;
    } else if (result === false) {
      console.log(`${RED}${filename}: MISMATCH${RESET}`);
      mismatchCount++;
    } else {
      // Skip files with invalid bytecode
      skippedCount++;
    }
  });

  console.log("----------------------------------------");
  console.log(`Total files: ${matchingFilenames.length}, Matches: ${matchCount}, Mismatches: ${mismatchCount}, Skipped: ${skippedCount}`);
}

compareAllBytecodes();
