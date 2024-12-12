# SOLO Token Staking System

A staking system for the SOLO token, allowing users to stake SOLO for sSOLO (Staked SOLO) and further stake sSOLO for rsSOLO (Restaked SOLO).

## Overview

This project implements a simple but powerful staking system with two levels:
- **SOLO → sSOLO**: Stake SOLO tokens to receive sSOLO tokens (1:1 ratio)
- **sSOLO → rsSOLO**: Stake sSOLO tokens to receive rsSOLO tokens (1:1 ratio)

The system follows similar principles to WETH (Wrapped Ether), allowing for seamless integration with DeFi protocols.

## Features

- 1:1 staking ratio at all levels
- No time locks on staking or unstaking
- No owner privileges
- Fully permissionless system
- Composable with other DeFi protocols
- depositTo/withdrawTo functionality for better UX

## Directory Structure
```
src/
├── mock/
│   └── SOLO.sol       # Mock SOLO token for testing
├── stakedSOLO.sol     # First level staking (SOLO → sSOLO)
└── restakedSOLO.sol   # Second level staking (sSOLO → rsSOLO)
```

## Installation

```shell
forge install
```

## Building

```shell
forge build
```

## Testing

Run all tests:
```shell
forge test
```

Run tests with higher verbosity:
```shell
forge test -vv
```

Run tests with gas reporting:
```shell
forge test --gas-report
```

### Test Coverage
The test suite includes:
- Basic unit tests for all functionalities
- Failure cases
- Fuzz testing for deposit/withdraw operations
- Integration tests between staking levels

## Deployment

1. Create a `.env` file with your deployment parameters:
```env
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
```

2. Run the deployment script:
```shell
# For testnet (e.g., Sepolia)
forge script script/DeploySOLO.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# For mainnet
forge script script/DeploySOLO.s.sol --rpc-url $ETH_RPC_URL --broadcast --verify
```

The deployment script will:
1. Deploy the SOLO token (or use existing)
2. Deploy StakedSOLO
3. Deploy RestakedSOLO
4. Output all contract addresses

## Contract Interactions

### Staking SOLO
```solidity
// Approve SOLO spending
SOLO.approve(address(StakedSOLO), amount);

// Stake SOLO for sSOLO
StakedSOLO.deposit(amount);
```

### Restaking sSOLO
```solidity
// Approve sSOLO spending
StakedSOLO.approve(address(RestakedSOLO), amount);

// Stake sSOLO for rsSOLO
RestakedSOLO.deposit(amount);
```

## Gas Optimization

View gas snapshots:
```shell
forge snapshot
```

## Format Code

```shell
forge fmt
```

## Security

Key security features:
- No owner privileges
- No time locks
- Standard ERC20 implementation
- Based on battle-tested WETH pattern
- Protected against common vulnerabilities

## License

MIT

