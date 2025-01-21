# SOLO Staking System Tests

## Overview
This document outlines the test suite for the SOLO Staking System, comprising the SOLOStaking contract and StSOLOToken contract. Our testing strategy focuses on comprehensive validation of staking operations, withdrawal mechanisms, rebasing functionality, and precise yield calculations across various scenarios.

## Test Environment Setup
Each test begins with a standardized environment setup that includes:
- Three primary accounts: owner (test contract), alice, and bob
- Optional extension to include additional accounts (e.g., charlie, david) for multi-user scenarios
- Deployment of MockSOLO token with 1M initial supply
- Deployment of StSOLOToken with 5% APR initial reward rate
- Deployment of SOLOStaking contract with 7-day withdrawal delay
- Initial token distribution to test accounts (1000 tokens each)
- Base stake to establish proper share-to-token ratio

## Core Functionality Tests

### Staking Operations

#### Basic Staking (`test_Stake`)
Tests the fundamental staking operation:
- Proper token transfer from user to staking contract
- Correct minting of stSOLO tokens
- Accurate event emission
- Balance updates with 1% deviation tolerance
- Verification of contract token balance

#### Staking for Others (`test_StakeForOther`)
Verifies the delegation feature:
- Allows one user to stake on behalf of another
- Ensures correct token ownership assignment
- Validates balance updates for all parties
- Verifies balance accuracy within 1% tolerance

### Share-Based Accounting Tests

#### Single User Share Accounting (`test_StakingAndShareAccounting`)
Validates core share-based mechanics:
- Initial share calculation verification
- Share-to-token conversion accuracy
- Share preservation during rebases
- Balance growth validation post-rebase

#### Multi-User Share Mechanics (`test_MultiUserStakingWithShares`)
Tests share distribution across users:
- Proportional share allocation
- Share calculation consistency
- Balance-to-share ratio maintenance
- 1% tolerance in share calculations

### Yield Calculation Tests

#### Single User Yield (`test_YieldCalculationSimpleSingle`)
Validates basic yield mechanics:
- 30-day yield calculation accuracy
- Rebase amount verification
- Expected vs actual yield comparison
- 0.5% tolerance in yield calculations

#### Multi-User Yield (`test_YieldCalculationSimpleMultiUser`)
Tests yield distribution across multiple users:
- Variable stake amounts (100-1000 tokens)
- Weekly rebase calculations
- Proportional yield verification
- Yield ratio maintenance between users
- Individual and aggregate yield tracking

#### Fuzzed Yield Testing (`test_YieldCalculationSingleFuzz`)
Property-based testing of yield mechanics:
- Random time periods (1-365 days)
- Variable stake amounts (bounded by available balance)
- Yield calculation consistency
- 0.5% tolerance maintenance

### Rebase Exclusion Tests

#### Pre-Excluded Rebase (`test_Exclude_FromRebasePreExcluded`)
Tests rebase behavior with pre-excluded accounts:
- Exclusion status verification
- Share accounting for excluded accounts
- Rebase isolation confirmation
- Balance preservation for excluded accounts

#### Exclusion Restrictions (`test_Exclude_RevertWhen_ExcludingAccountWithBalance`)
Validates exclusion mechanics:
- Prevention of excluding accounts with balance
- Proper error handling
- State consistency maintenance

#### Zero Balance Exclusion (`test_Exclude_CanExcludeAccountWithZeroBalance`)
Tests exclusion timing requirements:
- Successful exclusion of empty accounts
- Subsequent staking behavior
- Balance tracking post-exclusion

#### Exclusion Removal (`test_Exclude_CanRemoveExclusionRegardlessOfBalance`)
Verifies exclusion removal flexibility:
- Removal regardless of balance
- State updates post-removal
- Balance preservation during process

### Withdrawal Mechanism

#### Request Withdrawal (`test_RequestWithdrawal`)
Tests withdrawal initiation:
- stSOLO burning verification
- Withdrawal request recording
- Event emission accuracy
- Balance updates post-request

#### Process Withdrawal (`test_ProcessWithdrawal`)
Validates withdrawal completion:
- Delay period enforcement
- Token transfer accuracy
- Request status updates
- Event emission verification

#### Early Withdrawal Prevention (`test_RevertWhen_ProcessingEarlyWithdrawal`)
Tests timing constraints:
- Proper delay enforcement
- Error handling for early attempts
- State preservation

## Test Coverage Goals
The test suite verifies:
1. Share-based accounting accuracy across all operations
2. Yield calculation precision under various conditions
3. Rebase mechanics and exclusion system integrity
4. Multi-user interaction consistency
5. Withdrawal process security
6. Event emission accuracy
7. Mathematical precision in all calculations

## Test Organization Principles
Tests follow these key principles:
1. **Isolation**: Each test runs independently
2. **Clarity**: Test names clearly indicate functionality being tested
3. **Precision**: Exact validation with appropriate tolerances
4. **Comprehensiveness**: Coverage of simple and complex scenarios
5. **Documentation**: Clear comments explaining test purpose and methodology
6. **Logging**: Detailed state tracking for debugging

## Running the Tests
Execute the full test suite using:
```bash
forge test


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
