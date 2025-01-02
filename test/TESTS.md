# SOLO Staking System Tests

## Overview
This document outlines the test suite for the SOLO Staking System, which comprises the SOLOStaking contract and StSOLOToken contract. Our testing strategy focuses on ensuring the reliability and security of key staking operations, withdrawal mechanisms, and the rebasing functionality.

## Test Environment Setup
Each test begins with a standardized environment setup that includes:
- Three primary accounts: owner (test contract), alice, and bob
- Deployment of MockSOLO token with initial supply
- Deployment of StSOLOToken with 5% APR initial reward rate
- Deployment of SOLOStaking contract with 7-day withdrawal delay
- Initial token distribution to test accounts
- Base stake to establish proper share-to-token ratio

## Core Functionality Tests

### Initial Setup Verification (`test_InitialSetup`)
Validates the correct initialization of the staking system by verifying:
- Contract addresses are properly linked
- Initial withdrawal delay is set correctly
- Initial reward rate is configured as expected

### Staking Operations

#### Basic Staking (`test_Stake`)
Tests the fundamental staking operation:
- Proper token transfer from user to staking contract
- Correct minting of stSOLO tokens
- Accurate event emission
- Balance updates for both token types

#### Staking for Others (`test_StakeForOther`)
Verifies the delegation feature:
- Allows one user to stake on behalf of another
- Ensures correct token ownership assignment
- Validates balance updates for all parties

### Withdrawal Mechanism

#### Request Withdrawal (`test_RequestWithdrawal`)
Tests the initiation of the withdrawal process:
- Proper burning of stSOLO tokens
- Creation of withdrawal request record
- Correct event emission
- State updates in the withdrawal tracking system

#### Process Withdrawal (`test_ProcessWithdrawal`)
Validates the completion of withdrawals:
- Enforces withdrawal delay period
- Proper SOLO token transfer back to user
- Accurate updating of request status
- Correct event emission

### Rebasing Functionality

#### Basic Rebase (`test_Rebase`)
Tests the token rebasing mechanism:
- Correct reward calculation
- Proper balance adjustment for holders
- Accurate tracking of excluded addresses
- Event emission for rebase operations

#### Exclusion from Rebase (`test_ExcludeFromRebase`)
Verifies the exclusion system:
- Proper marking of excluded addresses
- Correct reward distribution among non-excluded holders
- Balance preservation for excluded addresses

### Administrative Functions

#### Update Reward Rate (`test_UpdateRewardRate`)
Tests the reward rate modification system:
- Proper permission checking
- Rate validation within acceptable bounds
- State updates and event emission

#### Update Withdrawal Delay (`test_UpdateWithdrawalDelay`)
Validates the delay period modification:
- Proper permission checking
- Bounds validation
- State updates and event emission

## Failure Cases

### Staking Failures
- `test_RevertWhen_StakingZero`: Ensures rejection of zero-amount stakes
- `test_RevertWhen_StakingToZeroAddress`: Verifies prevention of staking to invalid addresses

### Withdrawal Failures
- `test_RevertWhen_ProcessingEarlyWithdrawal`: Validates enforcement of withdrawal delay
- `test_RevertWhen_ProcessingNonexistentRequest`: Ensures proper request validation

### Administrative Failures
- `test_RevertWhen_SettingExcessiveRewardRate`: Validates upper bound on reward rates
- `test_RevertWhen_SettingExcessiveWithdrawalDelay`: Ensures delay periods remain reasonable

## Test Coverage Goals
The test suite aims to verify:
1. **State Transitions**: All contract state changes occur correctly
2. **Access Control**: Permission systems work as intended
3. **Economic Security**: Token economics remain sound under various conditions
4. **Edge Cases**: System handles extreme scenarios gracefully
5. **Event Accuracy**: All events are emitted with correct parameters
6. **Mathematical Precision**: Share calculations and rebasing maintain accuracy

## Running the Tests
Execute the full test suite using:
```bash
forge test
```

For detailed output including gas usage:
```bash
forge test -vv
```

For complete traces:
```bash
forge test -vvvv
```

## Test Organization Principles
Our tests follow these key principles:
1. **Isolation**: Each test runs independently
2. **Clarity**: Test names clearly indicate functionality being tested
3. **Completeness**: Coverage of both success and failure paths
4. **Precision**: Exact verification of expected values
5. **Documentation**: Clear comments explaining test purpose and methodology
