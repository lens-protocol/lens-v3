```
                                              @@@@@@@@@
                                        @@@@@@@@@@@@@@@@@@@@@
                                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@
                                  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                                @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
              @@@@@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@      @@@@@@@@@@@
        @@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@
      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@              @@@@@@@@@@@@@@              @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@          @@@@@@@   @@@@@@@@@         @@@@@@    @@@@@@@@@@@@@@@@@@@@@@@@@
  @@@@@@@@@@@@@@@@@@@@@@  @@        @@@@@@@@  @@@@@@   @       @@@@@@@@   @@@@@@@@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                                  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

# Lens Protocol V3

## Setup

### 1. Clone the Repository

```
git clone git@github.com:lens-protocol/lens-v3.git
```

or

```
git clone https://github.com/lens-protocol/lens-v3.git
```

### 2. Install dependencies

```
yarn
```

### 3. Compile

```
npx hardhat compile
```

### 4. Test

The test coverage is still in progress, and mostly not present in this version of the codebase.

### 5. Deploy

Fill the .env with your private key, your .env should look like this:

```
WALLET_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

Make sure your wallet has enough GRASS on Lens Testnet Network to deploy the contracts.

Run the following command, which deploys the full protocol with all present Rules & Actions, and also the Global Feed, Graph, and Username primitives.

```
yarn run deploy
```

## Lens Core Structure

The concept of Lens V3 is based on the following assumptions:
- Every EVM account is a Profile now (in Lens V2 a profile was an NFT)
- Accounts can be smart wallets (and in Lens Dashboard they are by default) and support bespoke Lens Social features (like account managers, etc.)
- The Protocol itself is a set of primitives (Feed, Graph, Group, Namespace) which are not necessarily connected with each other and each might be an entry point (in Lens V2 everything was all in the same LensHub contract which was an entry point for everything)
- The Protocol can be extended by developing new flavors of the primitives, Actions and Rules that can be applied to these primitives
- Action is assumed to be any contract that interacts with The Protocol
- Rule is seen more as a restrictive extension of the Protocol
- Our Primitive implementations (flavors) are RuleBased, so they all support adding Rules (with AND/OR chaining) and process them on set interactions

### Primitives

## Project Structure

The `contracts/` folder is divided into several main folders: `actions/`, `core/`, `extensions/`, `migration/` and `rules/`.
In the future, some of these folders might live under its own repository; during this early stages of Lens Protocol V3 development they coexist in this repo.

### Core

Contains the main contracts that make up the base Lens Protocol. These contracts are envisioned as non-opinionated and flexible, allowing for a wide range of use cases.
They already are "Lens-Flavoured", but the "Core"-core contracts are still split separately as FeedCode, GroupCore, GraphCore, NamespaceCore.
We expect developers to build upon them, inherit from them, extend the functionality, and be creative with them.

### Migration

Contains modified versions of the Feed and Graph primitives, which do not do any checks and just fill up the storage during the initial migration.
The migration would be run by us and nobody else could access the network during that time (so it's assumed to be safe to have no access control or checks).

### Extensions

Contains the bespoke implementations of contracts for Lens Dashboard and initial version of Lens Social Protocol.
These contracts are opinionated and are designed to achieve the best experience while using the Lens Dashboard.
These also serve as examples of how developers could build on top of the Core contracts.

### Rules

Contains contracts implementing Lens Rules. These also serve as examples of how developers could build their own Rules.

### Actions

Contains contracts implementing Lens Actions. These also serve as examples of how developers could build their own Actions.
