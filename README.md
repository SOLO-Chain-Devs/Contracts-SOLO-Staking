# SOLO Token Staking System

A sophisticated staking system for the SOLO token, implementing rebasing mechanics and withdrawal management through stSOLO (Staked SOLO) tokens.

## Overview

This project implements a robust staking system with the following core components:

- **SOLO → stSOLO**: Stake SOLO tokens to receive stSOLO tokens (initially 1:1 ratio)
- **Rebasing Mechanism**: stSOLO tokens appreciate in value through periodic rebases based on fixed annual emission
- **Withdrawal System**: Managed withdrawal process with configurable delay periods (0-30 days)
- **Dual Architecture**: Both standard and upgradeable contract versions available

The system follows modern staking principles similar to Lido's stETH, allowing for seamless integration with DeFi protocols while maintaining security through controlled withdrawal processes.

## Features

### Core Features
- **Share-based Accounting**: Efficient rebasing through share calculations
- **Block & Timestamp Tracking**: Enhanced security with `lastRebaseBlock` and `lastRebaseTime`
- **Configurable Parameters**: Withdrawal delay (0-30 days), rebase intervals (1 hour - 30 days)
- **Rebase Exclusion System**: Specific addresses can be excluded from rebasing rewards
- **Emergency Functions**: Owner can withdraw tokens in emergency situations
- **Fixed Annual Emission**: Predictable reward distribution based on `tokensPerYear`

## Directory Structure

```
src/
├── core/                          # Standard (non-upgradeable) contracts
│   ├── SOLOStaking.sol           # Core staking contract
│   ├── StSOLOToken.sol           # Rebasing staked SOLO token
│   ├── interfaces/
│   │   ├── ISOLOStaking.sol      # Staking contract interface
│   │   ├── IStSOLOToken.sol      # Token contract interface
│   │   └── IERC20.sol            # ERC20 interface
│   └── mock/
│       └── SOLOToken.sol         # Mock SOLO token for testing
├── upgradeable/                   # Upgradeable contract versions
│   ├── SOLOStaking.sol           # Upgradeable staking contract
│   ├── StSOLOToken.sol           # Upgradeable staked token
│   ├── interfaces/               # Upgradeable interfaces
│   └── lib/                      # Shared libraries
└── lib/                          # External dependencies
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
# For SOLO testnet
forge script script/Deploy.s.sol --rpc-url $SOLO_TESTNET_RPC_URL --broadcast --verify

# For other networks
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

The deployment script will:
1. Deploy upgradeable proxy implementations for all contracts
2. Deploy StSOLOToken with initial `tokensPerYear` emission rate
3. Deploy SOLOStaking with configured withdrawal delay
4. Set up contract permissions and links between contracts
5. Output all contract addresses and proxy addresses

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

// Request withdrawal (burns stSOLO immediately)
SOLOStaking.requestWithdrawal(stSOLOAmount);
```

### Processing Withdrawal

```solidity
// Process a pending withdrawal after delay period
SOLOStaking.processWithdrawal(requestId);
```

### Viewing System State

```solidity
// Get all withdrawal requests for an address
(soloAmounts, stSOLOAmounts, requestTimes, processed) = SOLOStaking.getPendingWithdrawals(userAddress);

// Check share information
uint256 shares = stSOLO.shareOf(userAddress);
uint256 tokenPerShare = stSOLO.getTokenPerShare();

// View rebase timing
uint256 lastRebase = stSOLO.lastRebaseTime();
uint256 lastBlock = stSOLO.lastRebaseBlock();

// Check if address is excluded from rebasing
bool isExcluded = stSOLO.excludedFromRebase(userAddress);
```

## Administrative Functions

### Managing Token Emission Rate

```solidity
// Update annual emission rate in tokens per year (only owner)
stSOLO.setRewardTokensPerYear(newTokensPerYear);

// Trigger manual rebase (owner or staking contract)
stSOLO.rebase();
```

### Managing Withdrawal Delay

```solidity
// Update withdrawal delay (only owner)
SOLOStaking.setWithdrawalDelay(newDelay);
```

### Managing Rebase System

```solidity
// Set address exclusion from rebases (only owner)
// Note: Can only exclude addresses with zero balance
stSOLO.setExcluded(address, excluded);

// Update rebase interval (only owner)
// Min: 1 hour, Max: 30 days
stSOLO.setRebaseInterval(newInterval);

// View excluded addresses
address[] memory excluded = stSOLO.getExcludedAddresses();
```

### Emergency Functions

```solidity
// Emergency token withdrawal (only owner)
SOLOStaking.emergencyWithdrawToken(tokenAddress, recipient, amount);
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

## Technical Details

### Constants and Limits
- **Withdrawal Delay**: 0 - 30 days
- **Rebase Interval**: 1 hour - 30 days (default: 12 hours)
- **Max Tokens Per Year**: 100,000,000,000 SOLO
- **Precision Factor**: 1e18 (for share calculations)

### Share-Based Accounting
The system uses a share-based model where:
- 1 SOLO initially equals 1 share
- `tokenPerShare` increases with each rebase
- User balance = shares * tokenPerShare / PRECISION_FACTOR
- Excluded addresses maintain 1:1 ratio

### Gas Mining Integration
The contracts include gas mining functionality for reward distribution based on gas usage patterns.

## License

MIT
