# TODO
## Personal TODO
- [ ] Clean up the smart contract and deployment values
- [ ] Update TODO tests
- [ ] Update this TODO file

## Core Questions
- [ ] Decide on rebase mechanism:
  - Manual rebase vs automatic rebase on transactions
  - Handling of whitelisted addresses in rebases
  - Zero address treatment in rebase calculations

## Proxy Implementation
- [ ] Add proxy support to contracts:
  - Basic UUPS proxy for StSOLOToken
  - Basic UUPS proxy for SOLOStaking
  - Write simple initialization functions

## Time Management
- [ ] Evaluate and implement timing:
  - Required timelock on deposits?
  - Required timelock on withdrawals?
  - Simple fixed periods vs variable periods

## Testing
- [ ] Basic test suite:
  - Core functionality tests
  - Proxy upgrade tests
  - Rebase mechanism tests
- [ ] Fuzz testing:
  - Deposit/withdraw operations
  - Rebase calculations
  - Share/token conversions

## Smart Contract Improvements
- [ ] Polish existing contracts:
  - Optimize gas usage
  - Improve error messages
  - Complete documentation
- [ ] Add proxy-related code:
  - Upgrade functions
  - Initialization logic
  - Storage considerations

## Security
- [ ] Basic security review
- [ ] Document main risks
- [ ] Plan for audit
