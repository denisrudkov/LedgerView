# LedgerView

On-chain financial analytics and accounting layer for Base network.

## Overview

LedgerView aggregates financial events from multiple contracts into a unified ledger for DAOs, treasuries, and automated payout systems.

## Features

- Append-only ledger with versioned entries
- Multi-source event aggregation
- Role-based classification and annotation
- Base Pay integration for USDC payments
- UUPS upgradeable architecture

## Modules

- **LedgerModule** - Core ledger entry management
- **RegistryModule** - Contract registration and configuration
- **ClassifierModule** - Transaction classification and tagging
- **IntegrationModule** - External system integrations

## Usage

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/Deploy.s.sol --rpc-url base-sepolia --broadcast
```

### Upgrade

```bash
PROXY_ADDRESS=0x... forge script script/Upgrade.s.sol --rpc-url base-sepolia --broadcast
```

## Architecture

All contracts use UUPS proxy pattern for upgradeability. Storage layout is designed for long-term stability.

## License

MIT

