// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SOLOStaking.sol";
import "../src/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract SOLOStakingFailingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    address public owner;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_AMOUNT = 1000 * 10**18;
    uint256 public constant INITIAL_REWARD_RATE = 500; // 5% APR
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(INITIAL_REWARD_RATE);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            INITIAL_WITHDRAWAL_DELAY
        );

        stSOLOToken.setStakingContract(address(stakingContract));

        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), 1 ether);
        stakingContract.stake(1 ether, alice);
        vm.stopPrank();
    }


    function test_ExcludeFromRebasePreExcluded() public {
        uint256 stakeAmount = 100 * 10**18;
        console.log("\n==================test_ExcludeFromRebasePreExcluded==========================");

        // Log initial state
        console.log("Initial total shares:", stSOLOToken.totalShares());
        console.log("Initial total supply:", stSOLOToken.totalSupply());

        // First, exclude Bob
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        console.log("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));

        // Then handle staking
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        console.log("\nAfter Alice stakes:");
        console.log("Alice shares:", stSOLOToken.shareOf(alice));
        console.log("Alice balance:", stSOLOToken.balanceOf(alice));
        console.log("Total shares:", stSOLOToken.totalShares());
        console.log("Total supply:", stSOLOToken.totalSupply());
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        console.log("\nAfter Bob stakes:");
        console.log("Bob shares:", stSOLOToken.shareOf(bob));
        console.log("Bob balance:", stSOLOToken.balanceOf(bob));
        console.log("Total shares:", stSOLOToken.totalShares());
        console.log("Total supply:", stSOLOToken.totalSupply());
        console.log("Excluded amount:", stSOLOToken.calculateExcludedAmount());
        vm.stopPrank();

        // Now Bob's stake will be properly isolated from the rebasing mechanism
        console.log("\nAlice before rebase:");
        console.log("Alice shares:", stSOLOToken.shareOf(alice));
        console.log("Alice balance:", stSOLOToken.balanceOf(alice));
        uint256 aliceBalanceBefore = stSOLOToken.balanceOf(alice);

        vm.warp(block.timestamp + 1 days);
        console.log("\nBefore rebase:");
        console.log("Bob shares:", stSOLOToken.shareOf(bob));
        console.log("Bob balance:", stSOLOToken.balanceOf(bob));

        uint256 rebaseAmount = stSOLOToken.rebase();
        console.log("\n===========================================After rebase:");
        console.log("Rebase amount:", rebaseAmount);
        console.log("Bob shares:", stSOLOToken.shareOf(bob));
        console.log("Bob balance:", stSOLOToken.balanceOf(bob));
        console.log("\nAlice after rebase:");
        console.log("Alice shares:", stSOLOToken.shareOf(alice));
        console.log("Alice balance:", stSOLOToken.balanceOf(alice));
        console.log("Total shares:", stSOLOToken.totalShares());
        console.log("Total supply:", stSOLOToken.totalSupply());
        uint256 aliceBalanceAfter = stSOLOToken.balanceOf(alice);

        // Add assertions for both accounts
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Bob's balance should remain fixed");
        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice's balance should increase after rebase");
        console.log("Alice's balance increase:", aliceBalanceAfter - aliceBalanceBefore);    
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount);
    }

    /**
        * @notice Tests the rebasing mechanism with excluded addresses
    * @dev Verifies that excluded addresses don't receive rebase rewards while others do
        */
    function test_ExcludeFromRebasePostExcluded() public {
        console.log("\n==================test_ExcludeFromRebasePostExcluded==========================");
        uint256 stakeAmount = 100 * 10**18;

        // Stage 1: Initial Staking
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        console.log("\nAfter Alice stakes:");
        console.log("Alice initial shares:", stSOLOToken.shareOf(alice));
        console.log("Alice initial balance:", stSOLOToken.balanceOf(alice));
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        console.log("\nAfter Bob stakes:");
        console.log("Bob initial shares:", stSOLOToken.shareOf(bob));
        console.log("Bob initial balance:", stSOLOToken.balanceOf(bob));
        vm.stopPrank();

        // Stage 2: Pre-Exclusion State
        console.log("\nPre-exclusion state:");
        console.log("Total supply:", stSOLOToken.totalSupply());
        console.log("Total shares:", stSOLOToken.totalShares());
        uint256 aliceBalanceBeforeExclusion = stSOLOToken.balanceOf(alice);
        uint256 bobBalanceBeforeExclusion = stSOLOToken.balanceOf(bob);

        // Stage 3: Apply Exclusion
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        console.log("\nPost-exclusion state:");
        console.log("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));
        console.log("Excluded amount:", stSOLOToken.calculateExcludedAmount());

        // Stage 4: First Rebase Period
        vm.warp(block.timestamp + 365 days);
        uint256 rebaseAmount = stSOLOToken.rebase();
        console.log("\nAfter first rebase:");
        console.log("Rebase amount:", rebaseAmount);

        // Stage 5: Final State Validation
        console.log("\nFinal states:");
        console.log("Alice final shares:", stSOLOToken.shareOf(alice));
        console.log("Alice final balance:", stSOLOToken.balanceOf(alice));
        console.log("Bob final shares:", stSOLOToken.shareOf(bob));
        console.log("Bob final balance:", stSOLOToken.balanceOf(bob));
        console.log("Total supply after rebase:", stSOLOToken.totalSupply());

        // Stage 6: Assertions
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Bob's balance should remain at stake amount");
        assertTrue(
            stSOLOToken.balanceOf(alice) > aliceBalanceBeforeExclusion,
            "Alice's balance should increase after rebase"
        );
        console.log("Alice's balance increase:",
                    stSOLOToken.balanceOf(alice) - aliceBalanceBeforeExclusion);
    }

    /**
        * @notice Tests the withdrawal request process
    * @dev Validates the withdrawal request creation and token burning
    */
    function test_RequestWithdrawal() public {
        // First stake some tokens
        uint256 stakeAmount = 100 * 10**18;
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);

        // Request withdrawal
        stSOLOToken.approve(address(stakingContract), stakeAmount);

        vm.expectEmit(true, false, false, true, address(stakingContract));
        emit WithdrawalRequested(alice, stakeAmount, stakeAmount, 0);

        stakingContract.requestWithdrawal(stakeAmount);
        vm.stopPrank();

        (uint256[] memory soloAmounts,,, bool[] memory processed) = 
            stakingContract.getPendingWithdrawals(alice);

        assertEq(soloAmounts[0], stakeAmount);
        assertFalse(processed[0]);
        assertEq(stSOLOToken.balanceOf(alice), 0);
    }

    /**
        * @notice Tests the withdrawal processing mechanism
    * @dev Verifies that withdrawals can be processed after delay period
    */
    function test_ProcessWithdrawal() public {
        // Setup: stake and request withdrawal
        uint256 stakeAmount = 100 * 10**18;
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        stSOLOToken.approve(address(stakingContract), stakeAmount);
        stakingContract.requestWithdrawal(stakeAmount);

        // Wait for withdrawal delay
        vm.warp(block.timestamp + stakingContract.withdrawalDelay() + 1);

        vm.expectEmit(true, false, false, true, address(stakingContract));
        emit WithdrawalProcessed(alice, stakeAmount, 0);

        stakingContract.processWithdrawal(0);
        vm.stopPrank();

        assertEq(soloToken.balanceOf(alice), INITIAL_AMOUNT);
        (,,,bool[] memory processed) = stakingContract.getPendingWithdrawals(alice);
        assertTrue(processed[0]);
    }

    /**
        * @notice Tests prevention of early withdrawal processing
    * @dev Verifies that withdrawals cannot be processed before delay period
    */
    function test_RevertWhen_ProcessingEarlyWithdrawal() public {
        uint256 stakeAmount = 100 * 10**18;
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        stSOLOToken.approve(address(stakingContract), stakeAmount);
        stakingContract.requestWithdrawal(stakeAmount);

        vm.expectRevert("Withdrawal delay not met");
        stakingContract.processWithdrawal(0);
        vm.stopPrank();
    }

    /**
        * @notice Tests the basic staking functionality
    * @dev Verifies token transfers and balance updates during staking
    */
    function test_Stake() public {
        uint256 stakeAmount = 100 * 10**18;

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);

        vm.expectEmit(true, true, false, true, address(stakingContract));
        emit Staked(alice, alice, stakeAmount);

        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        assertApproxEqRel(stSOLOToken.balanceOf(alice), stakeAmount, 1e16); // Allow 1% deviation
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmount + 1); // +1 from setup
    }

    /**
        * @notice Tests staking on behalf of another address
    * @dev Verifies delegation of staking benefits to another user
    */
    function test_StakeForOther() public {
        uint256 stakeAmount = 100 * 10**18;

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        assertApproxEqRel(stSOLOToken.balanceOf(bob), stakeAmount, 1e16);
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmount + 1);
    }

    event Staked(address indexed staker, address indexed recipient, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);
}
