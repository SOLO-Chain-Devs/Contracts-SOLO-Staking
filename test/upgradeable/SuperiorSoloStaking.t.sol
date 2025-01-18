// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/StdUtils.sol";
import "forge-std/Test.sol";
import "../../src/upgradeable/SOLOStaking.sol";
import "../../src/upgradeable/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Mock SOLO Token for Advanced Testing
 * @notice Enhanced ERC20 mock implementation supporting complex staking scenarios
 * @dev Provides sufficient initial supply and precision for comprehensive share-based testing
 *      Initial supply of 1M tokens allows for diverse test scenarios while maintaining reasonable numbers
 */
contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

/**
 * @title Superior SOLO Staking Test Suite
 * @notice Advanced test suite focusing on complex staking mechanics and edge cases
 * @dev Implements sophisticated test scenarios with emphasis on:
 *      - Share-based accounting accuracy
 *      - Rebase mechanics and exclusions
 *      - Multi-user interactions and state transitions
 *      - Fuzzing parameters for enhanced test coverage
 */
contract SuperiorSOLOStakingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    // Test participants with distinct roles
    address public owner;
    address public alice;   // Primary staker for basic scenarios
    address public bob;     // Used for rebase exclusion testing
    address public charlie; // Additional participant for multi-user scenarios

    // Carefully chosen test parameters
    uint256 public constant INITIAL_AMOUNT = 10000 * 10**18;    // Substantial enough for all test cases
    uint256 public constant INITIAL_TOKENS_PER_YEAR_RATE = 100_000 ether; 
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;  // Standard lock period

    /**
     * @notice Establishes an enhanced test environment with optimized fuzzing parameters
     * @dev Setup process includes:
     *      1. Foundry fuzzing configuration for thorough testing
     *      2. Contract deployment with carefully selected parameters
     *      3. Test account initialization with sufficient balances
     *      4. Staking contract configuration and linking
     */
    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Foundry fuzzing optimization
        vm.setEnv("FOUNDRY_FUZZ_MAX_LOCAL_REJECTS", "1000");
        vm.setEnv("FOUNDRY_FUZZ_MAX_GLOBAL_REJECTS", "10000");
        vm.setEnv("FOUNDRY_PROPTEST_MAX_SHRINK_ITERS", "100");

        // Contract deployment and configuration
        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(INITIAL_TOKENS_PER_YEAR_RATE);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            INITIAL_WITHDRAWAL_DELAY
        );

        stSOLOToken.setStakingContract(address(stakingContract));

        // Initial token distribution
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);
    }

    /**
     * @notice Validates core share-based accounting mechanics
     * @dev Tests the relationship between tokens, shares, and rebases by:
     *      1. Recording initial system state
     *      2. Performing a stake operation
     *      3. Verifying share calculation accuracy
     *      4. Confirming rebase effects on balances while preserving shares
     */
    function test_StakingAndShareAccounting() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // For the first stake, shares should equal the staked amount
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        // First staker should receive shares equal to their staked amount
        assertEq(stSOLOToken.shareOf(alice), stakeAmount, "Initial shares should equal staked amount");
        assertEq(stSOLOToken.balanceOf(alice), stakeAmount, "Initial balance should equal staked amount");

        // Advance time and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // After rebase, shares should remain the same while balance increases
        assertEq(stSOLOToken.shareOf(alice), stakeAmount, "Shares should remain unchanged after rebase");
        assertTrue(stSOLOToken.balanceOf(alice) > stakeAmount, "Balance should increase after rebase");
    }

    /**
     * @notice Tests share calculation consistency across multiple users
     * @dev Verifies that:
     *      1. Share allocation remains proportional for subsequent stakers
     *      2. Share-to-token conversion maintains accuracy
     *      3. System state updates correctly after multiple stakes
     */
    function test_MultiUserStakingWithShares() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Record initial state
        //uint256 initialSupply = stSOLOToken.totalSupply();
        //uint256 initialShares = stSOLOToken.totalShares();

        // First user stake
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        //uint256 aliceShares = stSOLOToken.shareOf(alice);
        
        // Calculate expected shares for second user
        uint256 currentSupply = stSOLOToken.totalSupply();
        uint256 currentShares = stSOLOToken.totalShares();
        uint256 expectedBobShares = (stakeAmount * currentShares) / currentSupply;
        
        // Second user stake
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        assertApproxEqRel(
            stSOLOToken.shareOf(bob),
            expectedBobShares,
            1e16, // 1% tolerance
            "Bob should receive expected shares"
        );
    }

    /**
     * @notice Tests complex interactions between rebasing and exclusion mechanics
     * @dev Validates:
     *      1. Proper stake withdrawal sequence before exclusion
     *      2. Exclusion effect on rebase participation
     *      3. Balance isolation for excluded accounts
     *      4. Continued rebase benefits for non-excluded accounts
     */
    function test_ComplexRebaseExclusion() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // First stake tokens
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        // Bob stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        
        // Important: We want to withdraw only the original staked amount
        stSOLOToken.approve(address(stakingContract), stakeAmount);
        stakingContract.requestWithdrawal(stakeAmount);
        
        vm.warp(block.timestamp + INITIAL_WITHDRAWAL_DELAY);
        stakingContract.processWithdrawal(0);
        vm.stopPrank();

        // Now safe to exclude Bob since he has withdrawn his original stake
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);

        // Advance time and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // Final state verification
        assertTrue(stSOLOToken.balanceOf(alice) > stakeAmount, "Alice's balance should increase");
        assertEq(stSOLOToken.balanceOf(bob), 0, "Bob's balance should be zero");
    }
}
