// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/StdUtils.sol";
import "forge-std/Test.sol";
import "../src/SOLOStaking.sol";
import "../src/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Mock SOLO Token
 * @notice Simple ERC20 mock for testing
 */
contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

/**
 * @title Superior SOLO Staking Test Suite
 * @notice Comprehensive test suite exploring complex staking scenarios
 * @dev Tests incorporate share-based accounting and rebase mechanics
 */
contract SuperiorSOLOStakingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    // Test participants
    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    // Constant test parameters
    uint256 public constant INITIAL_AMOUNT = 10000 * 10**18;
    uint256 public constant INITIAL_REWARD_RATE = 500; // 5% APR
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Setup foundry fuzzing parameters
        vm.setEnv("FOUNDRY_FUZZ_MAX_LOCAL_REJECTS", "1000");
        vm.setEnv("FOUNDRY_FUZZ_MAX_GLOBAL_REJECTS", "10000");
        vm.setEnv("FOUNDRY_PROPTEST_MAX_SHRINK_ITERS", "100");

        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(INITIAL_REWARD_RATE);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            INITIAL_WITHDRAWAL_DELAY
        );

        stSOLOToken.setStakingContract(address(stakingContract));

        // Distribute tokens
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);
    }

    function test_StakingAndShareAccounting() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Record initial total supply and shares
        uint256 initialSupply = stSOLOToken.totalSupply();
        uint256 initialShares = stSOLOToken.totalShares();
        
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        // Calculate expected shares using the same formula as the contract
        uint256 expectedShares = (stakeAmount * initialShares) / initialSupply;
        
        assertEq(stSOLOToken.shareOf(alice), expectedShares, "Shares should match expected calculation");
        assertTrue(stSOLOToken.balanceOf(alice) >= stakeAmount, "Balance should be at least stake amount");
    
        // Advance time and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // After rebase, shares should remain the same while balance increases
        assertEq(stSOLOToken.shareOf(alice), expectedShares, "Shares should remain unchanged after rebase");
        assertTrue(stSOLOToken.balanceOf(alice) > stakeAmount, "Balance should increase after rebase");
    }

    function test_MultiUserStakingWithShares() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Record initial state
        uint256 initialSupply = stSOLOToken.totalSupply();
        uint256 initialShares = stSOLOToken.totalShares();

        // First user stake
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        uint256 aliceShares = stSOLOToken.shareOf(alice);
        
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
