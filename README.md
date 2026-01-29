# Lens Protocol V3

Lens Protocol V3 is the modular evolution of the Lens social graph, designed with a modular architecture centered around Accounts, Primitives, Actions, and Rules.

## Prerequisites

Before you begin, ensure you have the following installed:
- [Node.js](https://nodejs.org/) & [Yarn](https://yarnpkg.com/)
- [Foundry](https://getfoundry.sh/) (for `forge` commands)

## Setup

### 1. Clone & Install
```bash
git clone https://github.com/lens-protocol/lens-v3.git
cd lens-v3
yarn install

```

### 2. Compile

You can compile for standard development or specifically for zkSync deployment.

```bash
# Standard Compile
npx hardhat compile

# zkSync Deployment Compile
forge b --zksync --suppress-warnings assemblycreate

```

### 3. Test

```bash
yarn coverage:report:filtered -vvv

```

### 4. Deploy

1. **Configure Environment:**
Create a `.env` file and add your private key:
```bash
WALLET_PRIVATE_KEY=0xYourPrivateKeyHere

```


2. **Fund Your Wallet:**
Get **GRASS** tokens from the [Lens Faucet](https://lens.xyz/docs/chain/using-lens-chain).
3. **Run Deployment:**
```bash
yarn run deploy

```



---

## Architecture Overview

Lens V3 moves away from the monolithic design of V2 (where everything was in `LensHub`) to a modular system based on these assumptions:

* **Profiles are Accounts:** Every EVM account is now a Profile (unlike V2, where profiles were NFTs).
* **Smart Wallets:** Accounts are designed to be smart wallets by default.
* **Decoupled Primitives:** The Protocol is a set of distinct primitives (**Feed, Graph, Group, Namespace**) that are not strictly coupled.
* **Extensibility:**
* **Actions:** Contracts that interact with the protocol.
* **Rules:** Restrictive logic (AND/OR chaining) applied to primitives.



## Project Structure

The repository is organized into the following core directories:

```text
contracts/
├── actions/      # Example implementations of Lens Actions
├── core/         # Base Primitives (Feed, Group, Graph, Namespace)
├── extensions/   # Implementations for Lens Dashboard & Social Protocol
├── migration/    # Unsafe primitives used only for initial migration
└── rules/        # Example implementations of Lens Rules

```

### Component Details

* **Core:** Non-opinionated base contracts (`FeedCode`, `GroupCore`, etc.) meant to be extended.
* **Extensions:** Opinionated contracts designed specifically for the Lens Dashboard experience.
* **Migration:** Simplified versions of primitives used strictly for data migration (no access control).
```
```