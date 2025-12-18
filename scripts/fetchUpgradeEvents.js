const fs = require("fs");
const { ethers } = require("ethers");

function parseArgs() {
  const raw = process.argv.slice(2);
  let addressBook = "addressBook.mainnet.json";
  let fromBlock = null;
  let only = null;

  for (let i = 0; i < raw.length; i++) {
    const a = raw[i];
    if (a && a.endsWith(".json")) {
      addressBook = a;
      continue;
    }
    if (a === "--from-block") {
      const v = raw[i + 1];
      if (!v) throw new Error("Missing value for --from-block");
      fromBlock = Number(v);
      if (!Number.isFinite(fromBlock) || fromBlock < 0) throw new Error(`Invalid --from-block: ${v}`);
      i++;
      continue;
    }
    if (a === "--only") {
      const v = raw[i + 1];
      if (!v) throw new Error("Missing value for --only");
      only = v;
      i++;
      continue;
    }
  }

  return { addressBook, fromBlock, only };
}

const cli = parseArgs();
const addressBookFile = cli.addressBook;
const networkName = addressBookFile.replace("addressBook.", "").replace(".json", "");

console.log(`Fetching upgrade events from: ${addressBookFile}`);
console.log(`Network: ${networkName}`);

// RPC URLs for different networks
const RPC_URLS = {
  mainnet: "https://rpc.lens.xyz",
  testnet: "https://rpc.testnet.lens.dev",
};

const rpcUrl = RPC_URLS[networkName] || RPC_URLS.mainnet;
console.log(`RPC URL: ${rpcUrl}`);

// Configuration
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 2000;
const RPC_TIMEOUT_MS = 2000;
const INITIAL_WINDOW_SIZE = 100000;
const MAX_WINDOW_SIZE = 100000;

// Contract type names
const ContractTypeNames = {
  0: "Implementation",
  1: "Beacon",
  2: "Factory",
  3: "Primitive",
  4: "Aux",
  5: "Action",
  6: "Rule",
  7: "Misc",
  8: "Address",
};

// Event topic hashes (from forge selectors list)
const EVENT_TOPICS = {
  // EIP1967 / BeaconProxy events
  Upgraded: "0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b",
  BeaconUpgraded: "0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e",
  AdminChanged: "0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f",
  AutoUpgradeChanged: "0x64f12e18668c99cfc55b56d82d85ca70324b29eca4f587a2171e94b8221053fe",

  // Beacon events
  ImplementationSetForVersion: "0x1d652902fba4119b8f1d07412816ab818be3e8b488f8eb49306472335cde47ac",
  DefaultVersionSet: "0xddb2013cf7f102d15447c4c1e94cf56823455f02eb244d0c3b2ef65163389346",

  // Lock events
  Lens_Lock_LockStatusSet_Global: "0x8ecce4741c993dacb6397c3a43bfba3d342e1fe1d800b632a636ff59e78dd692",
  Lens_Lock_LockStatusSet_Address: "0x73324da9958330578a9d21dce8e726e64c80c13385ecee232dd0675ec5234fb2",
};

// Reverse lookup: topic hash -> event name
const TOPIC_TO_EVENT = Object.fromEntries(Object.entries(EVENT_TOPICS).map(([k, v]) => [v.toLowerCase(), k]));

// Block timestamp cache
const blockTimestampCache = new Map();

// Sleep helper
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Retry wrapper
async function withRetry(fn, retries = MAX_RETRIES) {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === retries - 1) throw error;
      console.log(`   Retry ${i + 1}/${retries} after error: ${error.message}`);
      await sleep(RETRY_DELAY_MS * (i + 1));
    }
  }
}

function isTimeoutError(error) {
  if (!error) return false;
  const msg = String(error.message || error).toLowerCase();
  return (
    msg.includes("timed out") ||
    msg.includes("timeout") ||
    msg.includes("request timeout") ||
    msg.includes("operation timed out") ||
    String(error.code || "").toUpperCase() === "TIMEOUT"
  );
}

function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => {
        const e = new Error(`${label || "rpc call"} timed out after ${ms}ms`);
        e.code = "TIMEOUT";
        reject(e);
      }, ms)
    ),
  ]);
}

async function getCodeAtBlock(provider, address, blockNumber) {
  return await withRetry(() => provider.getCode(address, blockNumber));
}

async function findDeploymentBlock(provider, address, latestBlock) {
  // Binary-search the first block where code exists at `address`.
  // This is much faster than scanning logs from block 0.
  const latestCode = await getCodeAtBlock(provider, address, latestBlock);
  if (!latestCode || latestCode === "0x") {
    return null;
  }

  let lo = 0;
  let hi = latestBlock;
  let calls = 0;

  while (lo < hi) {
    const mid = Math.floor((lo + hi) / 2);
    const code = await getCodeAtBlock(provider, address, mid);
    calls++;
    if (!code || code === "0x") {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }

  return { deployBlock: lo, codeCalls: calls };
}

// Determine which events to fetch for each contract type and proxy type
function getEventsForContract(contractInfo, contractName) {
  const events = [];

  // Skip implementation contracts
  if (contractName.endsWith("Impl")) {
    return events;
  }

  // Beacon contracts
  if (contractInfo.contractType === 1) {
    events.push(EVENT_TOPICS.ImplementationSetForVersion);
    events.push(EVENT_TOPICS.DefaultVersionSet);
    return events;
  }

  // Lock contracts
  if (contractName.includes("Lock") || contractInfo.contractName === "Lock") {
    events.push(EVENT_TOPICS.Lens_Lock_LockStatusSet_Global);
    events.push(EVENT_TOPICS.Lens_Lock_LockStatusSet_Address);
    return events;
  }

  // BeaconProxy contracts (Primitives)
  if (contractInfo.proxyType === "BeaconProxy") {
    events.push(EVENT_TOPICS.Upgraded);
    events.push(EVENT_TOPICS.BeaconUpgraded);
    events.push(EVENT_TOPICS.AdminChanged);
    events.push(EVENT_TOPICS.AutoUpgradeChanged);
    return events;
  }

  // EIP1967 proxy contracts (Factories, Actions, Rules, Aux, Misc)
  if (contractInfo.proxyType === "EIP1967") {
    events.push(EVENT_TOPICS.Upgraded);
    events.push(EVENT_TOPICS.AdminChanged);
    return events;
  }

  return events;
}

// Decode event data based on event type
function decodeEventData(log, eventName) {
  const result = {
    eventName,
    param1: "-",
    param2: "-",
    param1Name: "-",
    param2Name: "-",
  };

  try {
    switch (eventName) {
      case "Upgraded":
        // Upgraded(address indexed implementation)
        result.param1Name = "implementation";
        result.param1 = ethers.getAddress("0x" + log.topics[1].slice(26));
        break;

      case "BeaconUpgraded":
        // BeaconUpgraded(address indexed beacon)
        result.param1Name = "beacon";
        result.param1 = ethers.getAddress("0x" + log.topics[1].slice(26));
        break;

      case "AdminChanged":
        // AdminChanged(address previousAdmin, address newAdmin)
        // These are NOT indexed, they are in data
        result.param1Name = "previousAdmin";
        result.param2Name = "newAdmin";
        if (log.data && log.data.length >= 130) {
          result.param1 = ethers.getAddress("0x" + log.data.slice(26, 66));
          result.param2 = ethers.getAddress("0x" + log.data.slice(90, 130));
        }
        break;

      case "AutoUpgradeChanged":
        // AutoUpgradeChanged(bool enabled)
        result.param1Name = "enabled";
        result.param1 = log.data ? BigInt(log.data) !== 0n : false;
        break;

      case "ImplementationSetForVersion":
        // ImplementationSetForVersion(uint256 indexed version, address indexed implementation)
        result.param1Name = "version";
        result.param2Name = "implementation";
        result.param1 = BigInt(log.topics[1]).toString();
        result.param2 = ethers.getAddress("0x" + log.topics[2].slice(26));
        break;

      case "DefaultVersionSet":
        // DefaultVersionSet(uint256 indexed version)
        result.param1Name = "version";
        result.param1 = BigInt(log.topics[1]).toString();
        break;

      case "Lens_Lock_LockStatusSet_Global":
        // Lens_Lock_LockStatusSet(bool indexed locked)
        result.param1Name = "locked";
        result.param1 = BigInt(log.topics[1]) !== 0n;
        break;

      case "Lens_Lock_LockStatusSet_Address":
        // Lens_Lock_LockStatusSet(address indexed target, bool indexed locked)
        result.param1Name = "target";
        result.param2Name = "locked";
        result.param1 = ethers.getAddress("0x" + log.topics[1].slice(26));
        result.param2 = BigInt(log.topics[2]) !== 0n;
        break;
    }
  } catch (error) {
    console.error(`   ⚠️  Error decoding ${eventName}: ${error.message}`);
  }

  return result;
}

// Helper to escape CSV values
function csvEscape(value) {
  if (value === undefined || value === null) return "-";
  const str = String(value);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str || "-";
}

// Helper to create CSV row
function csvRow(values) {
  return values.map(csvEscape).join(",");
}

// Format timestamp
function formatTimestamp(timestamp) {
  if (!timestamp) return "-";
  const date = new Date(timestamp * 1000);
  return date.toISOString().replace("T", " ").replace(/\.\d{3}Z$/, " UTC");
}

// Get block timestamp with caching
async function getBlockTimestamp(provider, blockNumber) {
  if (blockTimestampCache.has(blockNumber)) {
    return blockTimestampCache.get(blockNumber);
  }

  try {
    const block = await withRetry(() => provider.getBlock(blockNumber));
    const timestamp = block ? block.timestamp : 0;
    blockTimestampCache.set(blockNumber, timestamp);
    return timestamp;
  } catch (error) {
    console.error(`   Error getting block ${blockNumber}: ${error.message}`);
    return 0;
  }
}

async function getLogsOnce(provider, address, topics, fromBlock, toBlock, retries) {
  const startTime = Date.now();
  const label = `eth_getLogs(${address}, ${fromBlock}..${toBlock})`;
  const doCall = () =>
    withTimeout(
      provider.getLogs({
        address: address,
        topics: [topics],
        fromBlock: fromBlock,
        toBlock: toBlock,
      }),
      RPC_TIMEOUT_MS,
      label
    );

  const attempts = retries && retries > 1 ? retries : 1;
  let lastError = null;
  for (let i = 1; i <= attempts; i++) {
    try {
      const logs = await doCall();
      console.log(`      getLogs ok: ${fromBlock}..${toBlock} -> ${logs.length} log(s) in ${Date.now() - startTime}ms`);
      return logs;
    } catch (error) {
      lastError = error;
      // IMPORTANT: never retry on timeouts; the caller should split immediately.
      if (isTimeoutError(error)) {
        throw error;
      }
      if (i < attempts) {
        console.log(`      retry ${i}/${attempts - 1} after non-timeout error: ${error.message}`);
        await sleep(RETRY_DELAY_MS * i);
      }
    }
  }

  throw lastError;
}

// Adaptive fetching:
// - try single huge range
// - if timeout -> use 100k windows
// - if a window timeouts -> split in half and keep that smaller window size for rest of this contract
async function fetchLogsAdaptive(provider, address, topics, fromBlock, toBlock) {
  console.log(`      address=${address}`);
  console.log(`      topics[0] OR: ${JSON.stringify(topics)}`);
  console.log(`      range: ${fromBlock}..${toBlock}`);

  // First attempt: single request for the entire range.
  try {
    console.log(`      trying single-range getLogs...`);
    // IMPORTANT: do not retry the single-range request; if it times out, start splitting immediately.
    return await getLogsOnce(provider, address, topics, fromBlock, toBlock, 1);
  } catch (error) {
    if (!isTimeoutError(error)) {
      console.error(`      single-range getLogs failed (non-timeout): ${error.message}`);
      throw error;
    }
    console.log(`      single-range getLogs timed out; switching to windowed mode (${INITIAL_WINDOW_SIZE} blocks)`);
  }

  const allLogs = [];
  let cursor = fromBlock;
  let windowSize = INITIAL_WINDOW_SIZE;
  let successStreak = 0;

  while (cursor <= toBlock) {
    const end = Math.min(cursor + windowSize - 1, toBlock);
    try {
      // For windowed mode: retry ONLY on non-timeout errors.
      const chunk = await getLogsOnce(provider, address, topics, cursor, end, MAX_RETRIES);
      allLogs.push(...chunk);
      cursor = end + 1;
      // Only increase window after N consecutive successes (timeouts reset the streak).
      successStreak++;
      if (successStreak >= 10) {
        const nextWindow = Math.min(windowSize * 2, MAX_WINDOW_SIZE);
        if (nextWindow !== windowSize) {
          console.log(
            `      window ok (streak=${successStreak}); increasing windowSize ${windowSize} -> ${nextWindow}`
          );
          windowSize = nextWindow;
        }
        successStreak = 0;
      }
      continue;
    } catch (error) {
      if (!isTimeoutError(error)) {
        console.error(`      window getLogs failed (non-timeout) for ${cursor}..${end}: ${error.message}`);
        throw error;
      }

      const nextWindow = Math.floor(windowSize / 2);
      if (nextWindow < 1) {
        throw new Error(`Cannot split further; still timing out at 1-block window (at block ${cursor})`);
      }
      console.log(`      window ${cursor}..${end} timed out; splitting windowSize ${windowSize} -> ${nextWindow}`);
      windowSize = nextWindow;
      successStreak = 0;
      // retry same cursor with smaller window
    }
  }

  console.log(`      windowed mode complete: ${allLogs.length} total log(s)`);
  return allLogs;
}

async function fetchEventsForContract(provider, contractName, contractInfo, fromBlock, toBlock) {
  const events = [];
  const eventTopics = getEventsForContract(contractInfo, contractName);

  if (eventTopics.length === 0) {
    return events;
  }

  const address = contractInfo.address;
  console.log(`   Fetching ${eventTopics.length} event type(s) for ${address}`);

  try {
    // Resolve a tighter fromBlock by finding deployment block (unless user overrides)
    let effectiveFromBlock = fromBlock;
    if (cli.fromBlock !== null) {
      effectiveFromBlock = cli.fromBlock;
      console.log(`   Using CLI --from-block override: ${effectiveFromBlock}`);
    } else {
      console.log(`   Finding deployment block via getCode(binary search)...`);
      const dep = await findDeploymentBlock(provider, address, toBlock);
      if (!dep) {
        console.log(`   No code at latest block; skipping`);
        return events;
      }
      effectiveFromBlock = dep.deployBlock;
      console.log(`   Deployment block: ${effectiveFromBlock} (getCode calls: ${dep.codeCalls})`);
    }

    // Fetch logs (adaptive splitting on RPC timeouts)
    const logs = await fetchLogsAdaptive(provider, address, eventTopics, effectiveFromBlock, toBlock);

    // Process each log
    for (let i = 0; i < logs.length; i++) {
      const log = logs[i];
      console.log(`      Processing log ${i + 1}/${logs.length} block=${log.blockNumber} tx=${log.transactionHash}`);

      const eventName = TOPIC_TO_EVENT[log.topics[0].toLowerCase()];
      if (!eventName) {
        console.log(`      Unknown topic: ${log.topics[0]}`);
        continue;
      }

      // Get block timestamp (with caching)
      const timestamp = await getBlockTimestamp(provider, log.blockNumber);

      // Decode event data
      const decoded = decodeEventData(log, eventName);

      events.push({
        contractName,
        contractType: ContractTypeNames[contractInfo.contractType] || "Unknown",
        proxyType: contractInfo.proxyType || "-",
        address,
        blockNumber: log.blockNumber,
        timestamp,
        formattedTime: formatTimestamp(timestamp),
        transactionHash: log.transactionHash,
        eventName: decoded.eventName,
        param1Name: decoded.param1Name,
        param1: decoded.param1,
        param2Name: decoded.param2Name,
        param2: decoded.param2,
        logIndex: log.index,
      });
    }
  } catch (error) {
    console.error(`   Error fetching events for ${contractName}: ${error.message}`);
  }

  return events;
}

async function main() {
  // Read addressBook
  const addressBook = JSON.parse(fs.readFileSync(addressBookFile, "utf8"));

  // Setup provider with timeout
  const provider = new ethers.JsonRpcProvider(rpcUrl, undefined, {
    staticNetwork: true,
    batchMaxCount: 1,
  });

  // Get current block
  const latestBlock = await provider.getBlockNumber();
  console.log(`Latest block: ${latestBlock}`);

  // Output (append after every contract; resume if file already exists)
  const outputDir = "scripts/out";
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  const outputFile = `${outputDir}/upgrade_events_${networkName}.csv`;

  const headers = [
    "DateTime",
    "BlockNumber",
    "ContractName",
    "ContractType",
    "ProxyType",
    "Address",
    "EventName",
    "Param1Name",
    "Param1Value",
    "Param2Name",
    "Param2Value",
    "TransactionHash",
  ];

  function readProcessedContractsFromCsv(path) {
    const processed = new Set();
    if (!fs.existsSync(path)) return processed;
    const content = fs.readFileSync(path, "utf8");
    const lines = content.split("\n").filter((l) => l.trim().length > 0);
    // Skip header
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      // Simple split is safe here because none of our fields contain commas.
      const cols = line.split(",");
      const contractName = cols[2];
      if (contractName && contractName !== "-" && contractName !== "ContractName") {
        processed.add(contractName.replace(/^"|"$/g, ""));
      }
    }
    return processed;
  }

  // Ensure header exists if file is new/empty
  if (!fs.existsSync(outputFile) || fs.statSync(outputFile).size === 0) {
    fs.writeFileSync(outputFile, headers.map(csvEscape).join(",") + "\n");
  }

  const processedContracts = readProcessedContractsFromCsv(outputFile);
  if (processedContracts.size > 0) {
    console.log(`Resuming: found ${processedContracts.size} contract(s) already present in ${outputFile}`);
  }

  // Append helper
  function ensureFileEndsWithNewline(path) {
    if (!fs.existsSync(path)) return;
    const stat = fs.statSync(path);
    if (!stat || stat.size === 0) return;
    const fd = fs.openSync(path, "r");
    try {
      const buf = Buffer.alloc(1);
      fs.readSync(fd, buf, 0, 1, stat.size - 1);
      if (buf[0] !== 0x0a) {
        fs.appendFileSync(path, "\n");
      }
    } finally {
      fs.closeSync(fd);
    }
  }

  function appendEventsToCsv(events) {
    if (!events || events.length === 0) return;
    ensureFileEndsWithNewline(outputFile);
    const rows = events.map((e) =>
      csvRow([
        e.formattedTime,
        e.blockNumber,
        e.contractName,
        e.contractType,
        e.proxyType,
        e.address,
        e.eventName,
        e.param1Name,
        e.param1,
        e.param2Name,
        e.param2,
        e.transactionHash,
      ])
    );
    fs.appendFileSync(outputFile, rows.join("\n") + "\n");
  }

  // Running summaries (computed incrementally)
  const eventCounts = {};
  const contractCounts = {};

  // Filter contracts (skip Impl contracts and contracts without address)
  let contracts = Object.entries(addressBook).filter(([name, info]) => !name.endsWith("Impl") && info.address);
  if (cli.only) {
    contracts = contracts.filter(([name]) => name === cli.only);
    if (contracts.length === 0) {
      throw new Error(`--only ${cli.only} did not match any contract in ${addressBookFile}`);
    }
  }

  console.log(`\nProcessing ${contracts.length} contracts...\n`);

  let processedCount = 0;

  // Process each contract
  for (const [contractName, contractInfo] of contracts) {
    processedCount++;
    const eventTopics = getEventsForContract(contractInfo, contractName);

    if (eventTopics.length === 0) {
      console.log(`[${processedCount}/${contracts.length}] ${contractName}: no upgrade events to fetch`);
      continue;
    }

    if (processedContracts.has(contractName)) {
      console.log(`[${processedCount}/${contracts.length}] ${contractName}: already in CSV, skipping`);
      continue;
    }

    console.log(`\n[${processedCount}/${contracts.length}] ${contractName}`);

    const events = await fetchEventsForContract(provider, contractName, contractInfo, 0, latestBlock);

    if (events.length > 0) {
      console.log(`   Total: ${events.length} event(s)`);
      // Append immediately for resiliency
      appendEventsToCsv(events);
      processedContracts.add(contractName);

      // Update incremental summaries
      contractCounts[contractName] = (contractCounts[contractName] || 0) + events.length;
      for (const e of events) {
        eventCounts[e.eventName] = (eventCounts[e.eventName] || 0) + 1;
      }
    } else {
      console.log(`   No events found`);
    }
  }

  console.log(`\n✅ Results appended to: ${outputFile}`);

  // Print summary by event type (this run only; previously-written rows are not re-counted)
  console.log("\n📈 Events by type (this run):");
  for (const [eventName, count] of Object.entries(eventCounts).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${eventName}: ${count}`);
  }

  // Print summary by contract (this run only)
  console.log("\n📈 Events by contract (this run):");
  for (const [contractName, count] of Object.entries(contractCounts).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${contractName}: ${count}`);
  }
}

main().catch((error) => {
  console.error("Error in main execution:", error);
  process.exit(1);
});
