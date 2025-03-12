## Testnet Verification

0. Prepare the environment:
    1. Copy `.env.local` to `.env`
    2. Copy `addressBook.testnet.json` to `addressBook.json`
    3. Run `anvil-zksync fork --fork-url https://rpc.testnet.lens.dev` to start a forked network
1. Deploy Whitelisted Multicall from `0x56EDD365d9b00C82E5D3C09e5A295224e076321c` address
    1. `yarn upgrade:1:local:deployMulticall`
2. Deploy Implementations
3. Upgrade Beacons & Transparent Proxies
4. Verify that the upgrade was successful

## Real Upgrade

1. Deploy Whitelisted Multicall from `0x56EDD365d9b00C82E5D3C09e5A295224e076321c` address
  a. `yarn upgrade:1:deployMulticall`
2. Deploy Implementations
3. Upgrade Beacons & Transparent Proxies
4. Verify that the upgrade was successful
