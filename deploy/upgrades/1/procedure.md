## Testnet Verification

0. Prepare the environment:
  1. Copy `.env.local` to `.env`
  2. `cp addressBook.mirrorOnTestnet.json addressBook.json`
  3. Run `anvil-zksync fork --fork-url https://rpc.testnet.lens.dev` to start a forked network
1. Deploy Whitelisted Multicall from `0x56EDD365d9b00C82E5D3C09e5A295224e076321c` address
  1. Uncomment the Multicall Deployer PK (`MULTICALL_DEPLOYER_PRIVATE_KEY` for `0x56EDD...`)
  2. `yarn upgrade:1:local:deployMulticall`
2. Deploy Implementations
  1. Uncomment the Testnet DEPLOYER PK (`WALLET_PRIVATE_KEY` for `0x5FCD0...`)
  2. `yarn upgrade:1:local:deployImplementations`
3. Upgrade Beacons & Transparent Proxies
  1. Uncomment the Testnet Proxy Admin PK (`PROXY_ADMIN_PRIVATE_KEY` for `0x5FCD0...`)
  2. Uncomment the Testnet Beacon Owner PK (`BEACON_OWNER_PRIVATE_KEY` for `0x5FCD0...`)
  3. `yarn upgrade:1:local:upgrade`
4. Verify that the upgrade was successful
  1. Uncomment proper `RPC_URL` in `.env` (LOCAL NODE)
  2. Run `tsx scripts/verifyUpgrade.ts`
  3. Look for all green

## Real Upgrade

0. Prepare the environment:
  1. Copy `.env.mainnet` to `.env`
  2. `cp addressBook.mainnet.json addressBook.json`
1. Deploy Whitelisted Multicall from `0x56EDD365d9b00C82E5D3C09e5A295224e076321c` address
  1. Uncomment the Multicall Deployer PK (`MULTICALL_DEPLOYER_PRIVATE_KEY` for `0x56EDD...`)
  2. `yarn upgrade:1:mainnet:deployMulticall`
2. Deploy Implementations
  1. Uncomment the MAINNET DEPLOYER PK (`WALLET_PRIVATE_KEY` for `0x4018D0...`)
  2. `yarn upgrade:1:mainnet:deployImplementations`
3. Upgrade Beacons & Transparent Proxies
  1. Uncomment the MAINNET Proxy Admin PK (`PROXY_ADMIN_PRIVATE_KEY` for `0xaAFa82...`)
  2. Uncomment the MAINNET Beacon Owner PK (`BEACON_OWNER_PRIVATE_KEY` for `0xaAFa82...`)
  3. `yarn upgrade:1:mainnet:upgrade`
4. Verify that the upgrade was successful
  1. Uncomment proper `RPC_URL` in `.env` (MAINNET)
  2. Run `tsx scripts/verifyUpgrade.ts`
  3. Look for all green
