# SOLO Token Staking System

A sophisticated staking system for the SOLO token, implementing rebasing mechanics and withdrawal management through stSOLO (Staked SOLO) tokens.

## Overview

This project implements a robust staking system with the following core components:

- **SOLO → stSOLO**: Stake SOLO tokens to receive stSOLO tokens (initially 1:1 ratio)
- **Rebasing Mechanism**: stSOLO tokens appreciate in value through periodic rebases
- **Withdrawal System**: Managed withdrawal process with configurable delay periods

The system follows modern staking principles similar to Lido's stETH, allowing for seamless integration with DeFi protocols while maintaining security through controlled withdrawal processes.

## Features

- Dynamic staking ratio through rebasing mechanism
- Configurable withdrawal delay (0-30 days)
- Rebase exclusion system for specific addresses
- Owner-managed reward rates and system parameters
- Comprehensive share-based accounting
- Protection against common vulnerabilities through ReentrancyGuard
- Event emission for all major operations
- Detailed view functions for monitoring system state

## Directory Structure

```
src/
├── interfaces/
│   └── IERC20.sol     # ERC20 interface
├── StSOLOToken.sol    # Rebasing staked SOLO token
└── SOLOStaking.sol    # Core staking contract
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
- Unit tests for core functionalities
- Rebase mechanism testing
- Withdrawal system verification
- Share-based accounting validation
- Access control checks
- Integration tests between contracts
- Fuzz testing for edge cases

## Deployment

1. Create a `.env` file with your deployment parameters:
```env
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
INITIAL_REWARD_RATE=initial_reward_rate_in_basis_points
WITHDRAWAL_DELAY=initial_withdrawal_delay_in_seconds
```

2. Run the deployment script:
```shell
# For testnet (e.g., Sepolia)
forge script script/DeploySOLO.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# For mainnet
forge script script/DeploySOLO.s.sol --rpc-url $ETH_RPC_URL --broadcast --verify
```

The deployment script will:
1. Deploy or link to the existing SOLO token
2. Deploy StSOLOToken with initial reward rate
3. Deploy SOLOStaking with configured withdrawal delay
4. Set up contract permissions and links
5. Output all contract addresses

## Contract Interactions

### Staking SOLO

```solidity
// Approve SOLO spending
SOLO.approve(address(SOLOStaking), amount);

// Stake SOLO and receive stSOLO
SOLOStaking.stake(amount, recipient);
```

### Requesting Withdrawal

```solidity
// Approve stSOLO spending
stSOLO.approve(address(SOLOStaking), amount);

// Request withdrawal
SOLOStaking.requestWithdrawal(amount);
```

### Processing Withdrawal

```solidity
// Process a pending withdrawal after delay period
SOLOStaking.processWithdrawal(requestId);
```

### Viewing Withdrawal Status

```solidity
// Get all pending withdrawals for an address
SOLOStaking.getPendingWithdrawals(userAddress);
```

## Administrative Functions

### Managing Reward Rate

```solidity
// Update annual reward rate (only owner)
stSOLO.setRewardRate(newRate);
```

### Managing Withdrawal Delay

```solidity
// Update withdrawal delay (only owner)
SOLOStaking.setWithdrawalDelay(newDelay);
```

### Managing Rebase Exclusions

```solidity
// Set address exclusion from rebases (only owner)
stSOLO.setExcluded(address, excluded);
```

## Gas Optimization

View gas snapshots:
```shell
forge snapshot
```

The contracts implement various gas optimization techniques:
- Efficient share-based accounting
- Minimal storage operations
- Optimized array operations
- Strategic use of view functions

## Format Code

```shell
forge fmt
```

## Security Considerations

Key security features:
- ReentrancyGuard implementation
- Controlled withdrawal process
- Share-based accounting for rebasing
- Owner access control for critical functions
- Event emission for transparency
- Protected against common vulnerabilities
- Comprehensive testing suite

## License

MIT
