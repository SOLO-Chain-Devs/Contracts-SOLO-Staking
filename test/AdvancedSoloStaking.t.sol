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

    // HELPER functions
    function _createRepeatedString(string memory char, uint256 count) private pure returns (string memory) {
        string memory result = "";
        for(uint256 i = 0; i < count; i++) {
            result = string.concat(result, char);
        }
        return result;
    }

    function logHeader(string memory text) internal pure {
        string memory headerPadding = _createRepeatedString(unicode"═", 20);
        console.log(unicode"\n╔%s %s %s╗", headerPadding, text, headerPadding);
    }

    function logMajor(string memory text) internal pure {
        string memory majorPadding = _createRepeatedString(unicode"▓", 5);
        console.log(unicode"\n%s %s", majorPadding, text);
    }

    function logMinor(string memory text) internal pure {
        console.log(unicode"\n»%s", text);
    }

    // Combined logging functions
    function logHeaderWith(string memory text, uint256 value) internal pure {
        logHeader(text);
        logEth("Value:", value);
    }

    function logMajorWith(string memory text, uint256 value) internal pure {
        logMajor(text);
        logEth("Value:", value);
    }

    function logMinorWith(string memory text, bool value) internal pure {
        logMinor(text);
        logBool("Status:", value);
    }

    function _getPadding(string memory label) private pure returns (string memory) {
        uint256 length = bytes(label).length;
        if (length < 14) return "\t\t\t\t";
        if (length < 24) return "\t\t\t";
        if (length < 33) return "\t\t";
        return "\t";
    }

    // Public logging functions
    function logEth(string memory label, uint256 value) internal pure {
        string memory padding = _getPadding(label);
        console.log(
            string.concat("%s", padding, "%d.%d"),
            label,
            value / 1 ether,
            value % 1 ether
        );
    }

    function logBool(string memory label, bool value) internal pure {
        string memory padding = _getPadding(label);
        console.log(
            string.concat("%s", padding, "%s"),
            label,
            value ? "true" : "false"
        );
    }

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


    function test_Exclude_FromRebasePreExcluded() public {
        uint256 stakeAmount = 100 * 10**18;
        logHeader("test_Exclude_FromRebasePreExcluded");

        // Log initial state
        logEth("Initial total shares:", stSOLOToken.totalShares());
        logEth("Initial total supply:", stSOLOToken.totalSupply());

        // First, exclude Bob
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        logBool("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));

        // Then handle staking
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        logMinor("After Alice stakes:");
        logEth("Alice shares:", stSOLOToken.shareOf(alice));
        logEth("Alice balance:", stSOLOToken.balanceOf(alice));
        logEth("Total shares:", stSOLOToken.totalShares());
        logEth("Total supply:", stSOLOToken.totalSupply());
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        console.log("\nAfter Bob stakes:");
        logEth("Bob shares:", stSOLOToken.shareOf(bob));
        logEth("Bob balance:", stSOLOToken.balanceOf(bob));
        logEth("Total shares:", stSOLOToken.totalShares());
        logEth("Total supply:", stSOLOToken.totalSupply());
        logEth("Excluded amount:", stSOLOToken.calculateExcludedAmount());
        vm.stopPrank();

        // Now Bob's stake will be properly isolated from the rebasing mechanism
        console.log("\nAlice before rebase:");
        logEth("Alice shares:", stSOLOToken.shareOf(alice));
        logEth("Alice balance:", stSOLOToken.balanceOf(alice));
        uint256 aliceBalanceBefore = stSOLOToken.balanceOf(alice);

        vm.warp(block.timestamp + 1 days);
        console.log("\nBefore rebase:");
        logEth("Bob shares:", stSOLOToken.shareOf(bob));
        logEth("Bob balanc:", stSOLOToken.balanceOf(bob));

        uint256 rebaseAmount = stSOLOToken.rebase();
        logMajor("After rebase:");
        logEth("Rebase amount:", rebaseAmount);
        logEth("Bob shares:", stSOLOToken.shareOf(bob));
        logEth("Bob balance:", stSOLOToken.balanceOf(bob));
        console.log("\nAlice after rebase:");
        logEth("Alice shares:", stSOLOToken.shareOf(alice));
        logEth("Alice balance:", stSOLOToken.balanceOf(alice));
        logEth("Total shares:", stSOLOToken.totalShares());
        logEth("Total supply:", stSOLOToken.totalSupply());
        uint256 aliceBalanceAfter = stSOLOToken.balanceOf(alice);

        // Add assertions for both accounts
        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice's balance should increase after rebase");
        logEth("Alice's balance increase:", aliceBalanceAfter - aliceBalanceBefore);    
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Bob's balance should remain fixed");
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount);
    }


function test_YieldCalculationSimpleSingle() public {
    // Fixed values for clear verification
    uint256 daysToPass = 30;  // one month
    uint256 stakeAmount = 100 * 1e18;  // 100 tokens
    
    // Get initial timestamp
    uint256 startTime = vm.getBlockTimestamp();
    uint256 yearlyRate = INITIAL_REWARD_RATE;
    
    logHeader("test_YieldCalculationSimpleSingle");
    logMinor("Test Parameters:");
    logEth("Stake amount:", stakeAmount);
    logEth("Days to pass:", daysToPass);
    logEth("Start time:", startTime);
    
    // Perform staking
    vm.startPrank(alice);
    soloToken.approve(address(stakingContract), stakeAmount);
    stakingContract.stake(stakeAmount, alice);
    
    uint256 initialStSOLOBalance = stSOLOToken.balanceOf(alice);
    logEth("Initial stSOLO balance:", initialStSOLOBalance);
    vm.stopPrank();

    // Advance time
    vm.warp(startTime + (daysToPass * 1 days));
    uint256 newTimestamp = vm.getBlockTimestamp();
    assertEq(newTimestamp, startTime + (daysToPass * 1 days), "Time warp failed");
    
    // Perform rebase and collect results
    uint256 rebaseAmount = stSOLOToken.rebase();
    uint256 finalBalance = stSOLOToken.balanceOf(alice);
    
    // Calculate yields
    uint256 actualYield = finalBalance - initialStSOLOBalance;
    uint256 expectedYield = (initialStSOLOBalance * daysToPass * yearlyRate) / (365 * 10000);
    
    logMajor("Results:");
    logEth("Time elapsed:", newTimestamp - startTime);
    logEth("Rebase amount:", rebaseAmount);
    logEth("Final balance:", finalBalance);
    logEth("Actual yield:", actualYield);
    logEth("Expected yield:", expectedYield);
    
    // Verify results
    assertGt(finalBalance, initialStSOLOBalance, "Balance should increase after rebase");
    assertApproxEqRel(
        actualYield,
        expectedYield,
        5e15, // 0.5% tolerance
        "Yield calculation exceeded tolerance"
    );
}

    function test_YieldCalculationSimpleMultiUser() public {
        address[] memory users = new address[](4);
        uint256[] memory stakeAmounts = new uint256[](4);
        
        // Setup test users with different stake amounts
        users[0] = alice;        // our existing alice
        users[1] = bob;          // our existing bob
        users[2] = makeAddr("charlie");
        users[3] = makeAddr("david");
        
        stakeAmounts[0] = 100 * 1e18;   // 100 tokens
        stakeAmounts[1] = 250 * 1e18;   // 250 tokens
        stakeAmounts[2] = 500 * 1e18;   // 500 tokens
        stakeAmounts[3] = 1000 * 1e18;  // 1000 tokens
        
        // Give tokens to new users
        soloToken.transfer(users[2], 1000 * 1e18);
        soloToken.transfer(users[3], 1000 * 1e18);
        
        uint256 startTime = vm.getBlockTimestamp();
        uint256 yearlyRate = INITIAL_REWARD_RATE;
        
        logHeader("Multi-User Yield Test");
        logMinor("Initial Setup");
        
        // Track balances through time
        uint256[][] memory userBalances = new uint256[][](4);
        for(uint256 i = 0; i < 4; i++) {
            userBalances[i] = new uint256[](5); // Track 5 periods
        }
        
        // Initial stakes
        for(uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            soloToken.approve(address(stakingContract), stakeAmounts[i]);
            stakingContract.stake(stakeAmounts[i], users[i]);
            userBalances[i][0] = stSOLOToken.balanceOf(users[i]);
            vm.stopPrank();
            
            logMinor(string.concat("User ", vm.toString(i)));
            logEth("Initial stake:", stakeAmounts[i]);
            logEth("Initial stSOLO:", userBalances[i][0]);
        }
        
        // Simulate 4 weeks with weekly rebases
        for(uint256 week = 1; week <= 4; week++) {
            // Advance time by 1 week
            vm.warp(startTime + (week * 7 days));
            
            logMajor(string.concat("Week ", vm.toString(week)));
            
            // Perform rebase
            uint256 rebaseAmount = stSOLOToken.rebase();
            logEth("Rebase amount:", rebaseAmount);
            
            // Track all balances
            for(uint256 i = 0; i < users.length; i++) {
                uint256 currentBalance = stSOLOToken.balanceOf(users[i]);
                userBalances[i][week] = currentBalance;
                
                // Calculate and verify yield
                uint256 totalYield = currentBalance - userBalances[i][0];
                uint256 expectedYield = (userBalances[i][0] * (week * 7) * yearlyRate) / (365 * 10000);
                
                logMinor(string.concat("User ", vm.toString(i)));
                logEth("Current balance:", currentBalance);
                logEth("Total yield:", totalYield);
                logEth("Expected yield:", expectedYield);
                
                // Verify yield is within tolerance
                assertApproxEqRel(
                    totalYield,
                    expectedYield,
                    5e15, // 0.5% tolerance
                    string.concat("Yield mismatch for user ", vm.toString(i))
                );
                
                // Verify relative yields between users maintain proportions
                if(i > 0) {
                    uint256 yieldRatio = (totalYield * 1e18) / stakeAmounts[i];
                    uint256 previousYieldRatio = ((userBalances[0][week] - userBalances[0][0]) * 1e18) / stakeAmounts[0];
                    assertApproxEqRel(
                        yieldRatio,
                        previousYieldRatio,
                        1e16, // 1% tolerance for ratio comparison
                        "Yield ratios should be proportional"
                    );
                }
            }
        }
        
        // Final yield analysis
        logMajor("Final Analysis");
        for(uint256 i = 0; i < users.length; i++) {
            uint256 totalReturn = ((userBalances[i][4] - userBalances[i][0]) * 10000) / userBalances[i][0];
            logMinor(string.concat("User ", vm.toString(i)));
            logEth("Total return (bp):", totalReturn);
        }
    }

function test_YieldCalculationSingleFuzz(uint96 _daysToPass, uint96 _rawAmount) public {
    // First, bound the days reasonably
    uint256 daysToPass = bound(_daysToPass, 1, 365);
    
    // Calculate bounds for tokens considering decimals
    uint256 maxTokens = soloToken.balanceOf(alice) / 1e18;  // Convert to whole tokens
    uint256 numTokens = bound(_rawAmount, 1, maxTokens / 2);  // Stake up to half available
    uint256 stakeAmount = numTokens * 1e18;  // Convert back to token units
    
    // Get initial timestamp
    uint256 startTime = vm.getBlockTimestamp();
    uint256 yearlyRate = INITIAL_REWARD_RATE;
    
    logHeader("test_YieldCalculationFuzz");
    logMinor("Test Parameters:");
    logEth("Available tokens:", maxTokens * 1e18);
    logEth("Stake amount:", stakeAmount);
    logEth("Days to pass:", daysToPass);
    logEth("Start time:", startTime);
    
    // Perform staking
    vm.startPrank(alice);
    soloToken.approve(address(stakingContract), stakeAmount);
    stakingContract.stake(stakeAmount, alice);
    
    uint256 initialStSOLOBalance = stSOLOToken.balanceOf(alice);
    logEth("Initial stSOLO balance:", initialStSOLOBalance);
    vm.stopPrank();

    // Advance time
    vm.warp(startTime + (daysToPass * 1 days));
    uint256 newTimestamp = vm.getBlockTimestamp();
    assertEq(newTimestamp, startTime + (daysToPass * 1 days), "Time warp failed");
    
    // Perform rebase and collect results
    uint256 rebaseAmount = stSOLOToken.rebase();
    uint256 finalBalance = stSOLOToken.balanceOf(alice);
    
    // Calculate yields
    uint256 actualYield = finalBalance - initialStSOLOBalance;
    uint256 expectedYield = (initialStSOLOBalance * daysToPass * yearlyRate) / (365 * 10000);
    
    logMajor("Results:");
    logEth("Time elapsed:", newTimestamp - startTime);
    logEth("Rebase amount:", rebaseAmount);
    logEth("Final balance:", finalBalance);
    logEth("Actual yield:", actualYield);
    logEth("Expected yield:", expectedYield);
    
    // Verify results
    assertGt(finalBalance, initialStSOLOBalance, "Balance should increase after rebase");
    assertApproxEqRel(
        actualYield,
        expectedYield,
        5e15, // 0.5% tolerance
        "Yield calculation exceeded tolerance"
    );
}





    /**
     * @notice Tests that accounts with non-zero stSOLO balance cannot be excluded
     * @dev Verifies the new balance check requirement in setExcluded
     */
    function test_Exclude_RevertWhen_ExcludingAccountWithBalance() public {
        uint256 stakeAmount = 100 * 10**18;
        logHeader("test_Exclude_RevertWhen_ExcludingAccountWithBalance");
        
        // First, have Bob stake some tokens
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();
        
        logMinor("Initial state:");
        logEth("Bob's stSOLO balance:", stSOLOToken.balanceOf(bob));
        
        // Try to exclude Bob - should revert
        vm.prank(owner);
        vm.expectRevert("Cannot exclude account with non-zero balance");
        stSOLOToken.setExcluded(bob, true);
    }

    /**
     * @notice Tests exclusion of accounts with zero balance
     * @dev Verifies accounts can be excluded before staking
     */
    function test_Exclude_CanExcludeAccountWithZeroBalance() public {
        logHeader("test_Exclude_CanExcludeAccountWithZeroBalance");
        
        // Try to exclude Bob before he has any stake
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        
        logMinor("After exclusion:");
        logBool("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));
        
        // Now Bob stakes after being excluded
        uint256 stakeAmount = 100 * 10**18;
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();
        
        logMinor("After staking:");
        logEth("Bob's balance:", stSOLOToken.balanceOf(bob));
        
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Bob's balance should equal stake amount");
    }

    /**
     * @notice Tests removal of exclusion status regardless of balance
     * @dev Verifies exclusion can be removed even with non-zero balance
     */
    function test_Exclude_CanRemoveExclusionRegardlessOfBalance() public {
        logHeader("test_Exclude_CanRemoveExclusionRegardlessOfBalance");
        
        // First exclude Bob (when he has no balance)
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        
        logMinor("Initial exclusion:");
        logBool("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));
        
        // Bob stakes some tokens
        uint256 stakeAmount = 100 * 10**18;
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();
        
        logMinor("After staking:");
        logEth("Bob's balance:", stSOLOToken.balanceOf(bob));
        
        // Should be able to remove exclusion even with balance
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, false);
        
        logMinor("After removing exclusion:");
        logBool("Is Bob still excluded:", stSOLOToken.excludedFromRebase(bob));
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
