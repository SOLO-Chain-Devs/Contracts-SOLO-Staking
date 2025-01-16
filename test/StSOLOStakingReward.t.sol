// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SOLOStaking.sol";
import "../src/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

/**
 * @title Basic StSOLO Test Contract
 * @notice Test contract for StSOLO staking functionality with flexible parameters
 * @dev Contains tests for staking, rewards, and withdrawals with configurable APR and time periods
 */
contract BasicStSOLO is Test {
    // Contract instances
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    // Test accounts
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public david;
    // Configuration constants
    uint256 public constant INITIAL_AMOUNT = 1000 * 10 ** 18;
    uint256 public rewardRate; // APR in basis points (100 = 1%)
    uint256 public withdrawalDelay;
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public constant PRECISION = 0.001 ether; // Tolerance for approximate equality checks
    uint256 public REWARD_COVERAGE_AMOUNT = 10_000 ether;
    // Test parameters
    uint256 public baseStakeAmount;
    uint256 public largeStakeAmount;

    function setUp() public {
        // Initialize accounts
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        david = makeAddr("david");
        // Set configurable parameters
        rewardRate = 10_000; // 10% APR by default
        withdrawalDelay = 7 days;
        baseStakeAmount = 100 ether;
        largeStakeAmount = 500 ether;

        // Deploy contracts
        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(rewardRate);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            withdrawalDelay
        );

        stSOLOToken.setStakingContract(address(stakingContract));

        // Initial token distribution
        soloToken.transfer(address(stakingContract), REWARD_COVERAGE_AMOUNT);
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);
        soloToken.transfer(david, INITIAL_AMOUNT);
    }

    /**
     * @notice Tests if a user receives correct APY after one year
     * @dev Verifies that staking rewards are calculated correctly based on the reward rate
     */
    function test_User_Gets_Correct_APY() public {
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        // Advance time one year
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        
        // Calculate expected balance using tokensPerYear
        uint256 expectedYield = stSOLOToken.tokensPerYear();
        uint256 expectedBalance = baseStakeAmount + expectedYield;

        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            expectedBalance,
            PRECISION,
            "Incorrect rewards after one year"
        );
    }

    /**
     * @notice Tests if users staking same amounts receive equal rewards
     * @dev Verifies fairness in reward distribution for equal stakes
     */
    function test_Equal_Stakes_Equal_Rewards() public {
        // Alice Stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        // Bob Stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, bob);
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        
        // Calculate expected balance using tokensPerYear
        uint256 expectedYield = stSOLOToken.tokensPerYear();
        uint256 expectedBalance = baseStakeAmount + expectedYield / 2; // Divide by 2 since rewards are split between Alice and Bob
        
        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            expectedBalance,
            PRECISION,
            "Alice's balance incorrect"
        );
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            expectedBalance,
            PRECISION,
            "Bob's balance incorrect"
        );
    }

    /**
     * @notice Tests if rewards are proportional for different stake amounts
     * @dev Verifies that larger stakes receive proportionally larger rewards
     */
    function test_Proportional_Rewards() public {
        // Alice stakes base amount
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        // Bob stakes large amount (5x base amount)
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), largeStakeAmount);
        stakingContract.stake(largeStakeAmount, bob);
        vm.stopPrank();

        // Calculate total staked and proportions
        uint256 totalStaked = baseStakeAmount + largeStakeAmount;
        uint256 aliceProportion = baseStakeAmount * 1e18 / totalStaked;
        uint256 bobProportion = largeStakeAmount * 1e18 / totalStaked;
        
        // Advance time one year
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        
        // Calculate expected yields using tokensPerYear
        uint256 totalYield = stSOLOToken.tokensPerYear();
        uint256 aliceExpectedYield = (totalYield * aliceProportion) / 1e18;
        uint256 bobExpectedYield = (totalYield * bobProportion) / 1e18;
        
        // Calculate final expected balances
        uint256 expectedSmallBalance = baseStakeAmount + aliceExpectedYield;
        uint256 expectedLargeBalance = largeStakeAmount + bobExpectedYield;

        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            expectedSmallBalance,
            PRECISION,
            "Small stake rewards incorrect"
        );
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            expectedLargeBalance,
            PRECISION,
            "Large stake rewards incorrect"
        );
    }

    /**
     * @notice Tests staggered staking with multiple rebase periods
     * @dev Verifies correct reward calculation for different staking entry points
     */
    function test_Staggered_Staking_Rebase() public {

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        uint256 updatedTokenPerShare = stSOLOToken.getTokenPerShare();
        uint256 aliceExpectedBalance = calculateExpectedBalance(
            baseStakeAmount,
            updatedTokenPerShare
        );

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            aliceExpectedBalance,
            PRECISION,
            "Incorrect balance after staggered staking"
        );
    }

    /**
     * @notice Tests withdrawal process during rebase periods
     * @dev Verifies correct balance calculations during partial withdrawals
     */
    function test_Withdrawal_During_Rebase() public {
        uint256 withdrawalAmount = baseStakeAmount / 2;

        // Initial stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, bob);
        vm.stopPrank();

        // First rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Bob requests withdrawal
        vm.startPrank(bob);
        stSOLOToken.approve(address(stakingContract), withdrawalAmount);
        stakingContract.requestWithdrawal(withdrawalAmount);
        vm.stopPrank();

        // Second rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Validate final balances
        uint256 tokenPerShareAfterSecondRebase = stSOLOToken.getTokenPerShare();
        uint256 aliceExpectedBalance = calculateExpectedBalance(
            baseStakeAmount,
            tokenPerShareAfterSecondRebase
        );

        uint256 remainingSharesBob = stSOLOToken.shareOf(bob);
        uint256 bobExpectedBalance = (remainingSharesBob * tokenPerShareAfterSecondRebase) / 1e18;

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            aliceExpectedBalance,
            PRECISION,
            "Alice's final balance incorrect"
        );
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            bobExpectedBalance,
            PRECISION,
            "Bob's final balance incorrect"
        );
    }

    /**
     * @notice Helper function to calculate expected balance based on shares
     * @param initialStake Initial amount staked
     * @param tokenPerShare Current token per share ratio
     * @return Expected balance after applying share ratio
     */
    function calculateExpectedBalance(
        uint256 initialStake,
        uint256 tokenPerShare
    ) internal pure returns (uint256) {
        return (initialStake * tokenPerShare) / 1e18;
    }

    /**
     * @notice Tests complex staking scenario with multiple users, rebases, and withdrawals
     * @dev Simulates real-world staking patterns with different entry points and actions
     */
    function test_Complex_Staking_Sequence() public {
        soloToken.transfer(david, INITIAL_AMOUNT);

        uint256 firstStake = 200 ether;
        uint256 secondStake = 300 ether;
        uint256 thirdStake = 150 ether;
        uint256 fourthStake = 250 ether;

        // First user (Alice) stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), firstStake);
        stakingContract.stake(firstStake, alice);
        vm.stopPrank();

        // First rebase period
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Second rebase period
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Second user (Bob) stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), secondStake);
        stakingContract.stake(secondStake, bob);
        vm.stopPrank();

        // Store Alice's balance after Bob's entry
        //uint256 aliceBalanceAfterBobEntry = stSOLOToken.balanceOf(alice);

        // Third rebase period
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Third user (Charlie) stakes
        vm.startPrank(charlie);
        soloToken.approve(address(stakingContract), thirdStake);
        stakingContract.stake(thirdStake, charlie);
        vm.stopPrank();

        // Fourth rebase period
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Bob requests a partial withdrawal
        uint256 withdrawAmount = 100 ether;
        vm.startPrank(bob);
        stSOLOToken.approve(address(stakingContract), withdrawAmount);
        stakingContract.requestWithdrawal(withdrawAmount);
        vm.stopPrank();

        // Fourth user (David) stakes
        vm.startPrank(david);
        soloToken.approve(address(stakingContract), fourthStake);
        stakingContract.stake(fourthStake, david);
        vm.stopPrank();

        // Fifth rebase period
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Process Bob's withdrawal
        vm.warp(block.timestamp + withdrawalDelay);
        vm.startPrank(bob);
        stakingContract.processWithdrawal(0);
        vm.stopPrank();

        // Final rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Verify final balances and states
        uint256 aliceFinalBalance = stSOLOToken.balanceOf(alice);
        uint256 bobFinalBalance = stSOLOToken.balanceOf(bob);
        uint256 charlieFinalBalance = stSOLOToken.balanceOf(charlie);
        uint256 davidFinalBalance = stSOLOToken.balanceOf(david);

        // Assert that balances have increased from initial stakes
        assertGt(aliceFinalBalance, firstStake, "Alice's balance should have increased");
        assertGt(bobFinalBalance, secondStake - withdrawAmount, "Bob's balance should have increased despite withdrawal");
        assertGt(charlieFinalBalance, thirdStake, "Charlie's balance should have increased");
        assertGt(davidFinalBalance, fourthStake, "David's balance should have increased");

        // Verify relative rewards (earlier stakers should have more rewards)
        assertGt(
            (aliceFinalBalance - firstStake) * 1e18 / firstStake,
            (davidFinalBalance - fourthStake) * 1e18 / fourthStake,
            "Earlier staker (Alice) should have relatively more rewards than later staker (David)"
        );

        // Verify Bob's withdrawal was processed
        (uint256 bobWithdrawalRequest, , , bool processed) = stakingContract.withdrawalRequests(bob, 0);
        assertTrue(processed, "Bob's withdrawal should be processed");
        assertEq(bobWithdrawalRequest, withdrawAmount, "Withdrawal amount should match request");

        // Verify system state is consistent
        uint256 totalStaked = firstStake + secondStake + thirdStake + fourthStake; 
        uint256 contractBalance = soloToken.balanceOf(address(stakingContract));
        assertGe(contractBalance, totalStaked - withdrawAmount, "Contract should have sufficient SOLO tokens");
    }

    function test_Multiple_Unstaking_Sequences() public {
        // Initial balances
        uint256 aliceInitialSolo = soloToken.balanceOf(alice);
        uint256 bobInitialSolo = soloToken.balanceOf(bob);
        uint256 charlieInitialSolo = soloToken.balanceOf(charlie);
        //uint256 davidInitialSolo = soloToken.balanceOf(david);

        // Track SOLO received from withdrawals
        uint256 aliceTotalWithdrawn = 0;
        uint256 bobTotalWithdrawn = 0;
        uint256 charlieTotalWithdrawn = 0;
        uint256 davidTotalWithdrawn = 0;

        // Initial stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), 200 ether);
        stakingContract.stake(200 ether, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Bob stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), 300 ether);
        stakingContract.stake(300 ether, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Charlie stakes
        vm.startPrank(charlie);
        soloToken.approve(address(stakingContract), 150 ether);
        stakingContract.stake(150 ether, charlie);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // David stakes
        vm.startPrank(david);
        soloToken.approve(address(stakingContract), 250 ether);
        stakingContract.stake(250 ether, david);
        vm.stopPrank();

        // First round of withdrawals
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Alice withdraws first portion
        uint256 aliceFirstWithdraw = 50 ether;
        vm.startPrank(alice);
        stSOLOToken.approve(address(stakingContract), aliceFirstWithdraw);
        stakingContract.requestWithdrawal(aliceFirstWithdraw);
        vm.stopPrank();

        // Bob withdraws first portion
        uint256 bobFirstWithdraw = 100 ether;
        vm.startPrank(bob);
        stSOLOToken.approve(address(stakingContract), bobFirstWithdraw);
        stakingContract.requestWithdrawal(bobFirstWithdraw);
        vm.stopPrank();

        // Process first withdrawals after delay
        vm.warp(block.timestamp + withdrawalDelay);
        
        vm.startPrank(alice);
        stakingContract.processWithdrawal(0);
        aliceTotalWithdrawn += aliceFirstWithdraw;
        vm.stopPrank();

        vm.startPrank(bob);
        stakingContract.processWithdrawal(0);
        bobTotalWithdrawn += bobFirstWithdraw;
        vm.stopPrank();

        // Second round of withdrawals
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Charlie first withdrawal
        uint256 charlieFirstWithdraw = 25 ether;
        vm.startPrank(charlie);
        stSOLOToken.approve(address(stakingContract), charlieFirstWithdraw);
        stakingContract.requestWithdrawal(charlieFirstWithdraw);
        vm.stopPrank();

        // David first withdrawal
        uint256 davidFirstWithdraw = 100 ether;
        vm.startPrank(david);
        stSOLOToken.approve(address(stakingContract), davidFirstWithdraw);
        stakingContract.requestWithdrawal(davidFirstWithdraw);
        vm.stopPrank();

        // Process second round after delay
        vm.warp(block.timestamp + withdrawalDelay);

        vm.startPrank(charlie);
        stakingContract.processWithdrawal(0);
        charlieTotalWithdrawn += charlieFirstWithdraw;
        vm.stopPrank();

        vm.startPrank(david);
        stakingContract.processWithdrawal(0);
        davidTotalWithdrawn += davidFirstWithdraw;
        vm.stopPrank();

        // Third round - withdraw all remaining
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Request final withdrawals
        vm.startPrank(alice);
        console.log("Alice's second withdrawal...");
        uint256 aliceRemaining = stSOLOToken.balanceOf(alice);
        stSOLOToken.approve(address(stakingContract), aliceRemaining);
        stakingContract.requestWithdrawal(aliceRemaining);
        aliceRemaining = stSOLOToken.balanceOf(alice);
        console.log("Alice remaining after withdrawal: %s", aliceRemaining);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobRemaining = stSOLOToken.balanceOf(bob);
        stSOLOToken.approve(address(stakingContract), bobRemaining);
        stakingContract.requestWithdrawal(bobRemaining);
        vm.stopPrank();

        vm.startPrank(charlie);
        uint256 charlieRemaining = stSOLOToken.balanceOf(charlie);
        stSOLOToken.approve(address(stakingContract), charlieRemaining);
        stakingContract.requestWithdrawal(charlieRemaining);
        vm.stopPrank();

        vm.startPrank(david);
        uint256 davidRemaining = stSOLOToken.balanceOf(david);
        stSOLOToken.approve(address(stakingContract), davidRemaining);
        //stakingContract.requestWithdrawal(davidRemaining);
        vm.stopPrank();

        // Process final withdrawals
        vm.warp(block.timestamp + withdrawalDelay);

        vm.startPrank(alice);
        stakingContract.processWithdrawal(1);
        aliceTotalWithdrawn += soloToken.balanceOf(alice) - aliceInitialSolo;
        vm.stopPrank();

        vm.startPrank(bob);
        stakingContract.processWithdrawal(1);
        bobTotalWithdrawn += soloToken.balanceOf(bob) - bobInitialSolo;
        vm.stopPrank();

        vm.startPrank(charlie);
        stakingContract.processWithdrawal(1);
        charlieTotalWithdrawn += soloToken.balanceOf(charlie) - charlieInitialSolo;
        vm.stopPrank();

        vm.startPrank(david);
        //stakingContract.processWithdrawal(1);
        //davidTotalWithdrawn += soloToken.balanceOf(david) - davidInitialSolo;
        vm.stopPrank();

        // Log final results
        console.log("Alice total SOLO received:", aliceTotalWithdrawn);
        console.log("Bob total SOLO received:", bobTotalWithdrawn);
        console.log("Charlie total SOLO received:", charlieTotalWithdrawn);
        //console.log("David total SOLO received:", davidTotalWithdrawn);

        // Calculate and log APY each user effectively received
        
        //uint256 davidAPY = ((davidTotalWithdrawn - 250 ether) * 10000) / (250 ether);
        (uint256 aliceWholePercent, uint256 aliceDecimals) = calculateAPYPercentage(
            soloToken.balanceOf(alice),
            aliceInitialSolo,
            200 ether
        );
        (uint256 bobWholePercent, uint256 bobDecimals) = calculateAPYPercentage(
            soloToken.balanceOf(bob),
            bobInitialSolo,
            300 ether
        );
        (uint256 charlieWholePercent, uint256 charlieDecimals) = calculateAPYPercentage(
            soloToken.balanceOf(charlie),
            charlieInitialSolo,
            150 ether
        );
        console.log("Alice APY: %s.%s%%", aliceWholePercent, aliceDecimals);
        console.log("Bob APY: %s.%s%%", bobWholePercent, bobDecimals);
        console.log("Charlie APY: %s.%s%%", charlieWholePercent, charlieDecimals);
        //console.log("David effective APY (basis points):", davidAPY);
    }
        function calculateAPYPercentage(
        uint256 currentBalance,
        uint256 initialBalance,
        uint256 stakedAmount
    ) public pure returns (uint256, uint256) {
        // Let me think about the order of operations...

        // First, calculate raw APY in basis points
        uint256 rawAPY = ((currentBalance - initialBalance) * 10000) / stakedAmount;

        // Now, convert to percentage components...
        // For 10.01%, we need:
        // - whole number part (10)
        // - decimal part (01)

        // Calculate whole number percentage
        uint256 wholeNumber = (rawAPY * 100) / 10000;  // This gives us the 10 in 10.01

        // Calculate decimal places
        uint256 decimals = ((rawAPY * 100) / 100) % 100;  // This gives us the 01 in 10.01

        return (wholeNumber, decimals);
    }
}
