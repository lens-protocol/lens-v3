// SPDX-License-Identifier: GPL-3.0-only

import * as fs from 'fs';
import * as path from 'path';

const sourceDir = path.join(__dirname, 'out', '__ABIS__');
const targetDir = path.join(__dirname, 'out', 'abis');

if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

function consolidateAbis(dir: string) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      consolidateAbis(srcPath);
    } else if (entry.isFile() && entry.name.endsWith('.abi.json')) {
      const targetPath = path.join(targetDir, entry.name);
      fs.copyFileSync(srcPath, targetPath);
      console.log(`Copied ${srcPath} to ${targetPath}`);
    }
  }
}

try {
  consolidateAbis(sourceDir);
  console.log('ABI consolidation complete!');
} catch (error) {
  console.error('An error occurred:', error);
}
