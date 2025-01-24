// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/upgradeable/SOLOStaking.sol";
import "../../src/upgradeable/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/upgradeable/lib/SOLOToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";



contract SOLOStakingFailingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    SOLOToken public soloToken;

    address public owner;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_AMOUNT = 1000 * 10**18;
    uint256 public constant INITIAL_TOKENS_PER_YEAR_RATE = 100_000 ether; 
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

    // Deploy implementations
    SOLOToken soloTokenImplementation = new SOLOToken();
    StSOLOToken stSOLOImplementation = new StSOLOToken();
    SOLOStaking stakingImplementation = new SOLOStaking();

    // Deploy SOLO token proxy
    bytes memory soloInitData = abi.encodeWithSelector(
        SOLOToken.initialize.selector
    );
    ERC1967Proxy soloProxy = new ERC1967Proxy(
        address(soloTokenImplementation),
        soloInitData
    );
    soloToken = SOLOToken(address(soloProxy));

    // Deploy StSOLO token proxy
    bytes memory stSOLOInitData = abi.encodeWithSelector(
        StSOLOToken.initialize.selector,
        INITIAL_TOKENS_PER_YEAR_RATE
    );
    ERC1967Proxy stSOLOProxy = new ERC1967Proxy(
        address(stSOLOImplementation),
        stSOLOInitData
    );
    stSOLOToken = StSOLOToken(address(stSOLOProxy));

    // Deploy SOLOStaking proxy
    bytes memory stakingInitData = abi.encodeWithSelector(
        SOLOStaking.initialize.selector,
        address(soloToken),
        address(stSOLOToken),
        INITIAL_WITHDRAWAL_DELAY
    );
    ERC1967Proxy stakingProxy = new ERC1967Proxy(
        address(stakingImplementation),
        stakingInitData
    );
    stakingContract = SOLOStaking(address(stakingProxy));

    // Set staking contract for StSOLO token
    vm.prank(owner);
    stSOLOToken.setStakingContract(address(stakingContract));

    // Mint tokens and distribute to test accounts
    soloToken.mintTo(owner, 1_000_000 ether);
    soloToken.transfer(alice, INITIAL_AMOUNT);
    soloToken.transfer(bob, INITIAL_AMOUNT);

    // Approve staking contract for alice
    vm.startPrank(alice);
    soloToken.approve(address(stakingContract), 1 ether);
    // Uncomment the line below if you want to start with a stake
    // stakingContract.stake(1 ether, alice);
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
    
    // New calculation based on tokensPerYear
    uint256 timeElapsed = daysToPass * 1 days;
    uint256 expectedYield = (stSOLOToken.tokensPerYear() * timeElapsed) / stSOLOToken.SECONDS_PER_YEAR();
    
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
    * @notice Tests yield calculation in a multi-user staking scenario
    * @dev Simulates 4 users staking different amounts and verifies yield distribution
    *      Uses the share-based tokenPerShare system for calculations 
    *      Each user's yield should be proportional to their shares
    */
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
               uint256 timeElapsed = week * 7 days;
               
               // Calculate expected yield using share-based model
               uint256 shares = stSOLOToken.shareOf(users[i]);
               uint256 periodRebaseAmount = (stSOLOToken.tokensPerYear() * timeElapsed) / stSOLOToken.SECONDS_PER_YEAR();
               uint256 shareIncrement = (periodRebaseAmount * stSOLOToken.PRECISION_FACTOR() * 2) / stSOLOToken.getTotalNormalShares();
               uint256 expectedYield = (shares * shareIncrement) / stSOLOToken.PRECISION_FACTOR();
               
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
    
    // Calculate expected yield using tokensPerYear method
    uint256 timeElapsed = daysToPass * 1 days;
    uint256 expectedYield = (stSOLOToken.tokensPerYear() * timeElapsed) / stSOLOToken.SECONDS_PER_YEAR();

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
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmount); // +1 from setup
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
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmount);
    }


    function test_ProcessWithdrawalTwo() public {
    // Setup: stake and request withdrawal
        uint256 stakeAmount = 100 * 10**18;

        vm.startPrank(alice);

        // Record initial SOLO balance
        uint256 initialSoloBalance = soloToken.balanceOf(alice);

        // Perform staking
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);

        // Record stSOLO balance after staking
        uint256 stSOLOBalance = stSOLOToken.balanceOf(alice);

        // Request withdrawal using stSOLO balance instead of fixed amount
        stSOLOToken.approve(address(stakingContract), stSOLOBalance);
        stakingContract.requestWithdrawal(stSOLOBalance);

        // Wait for withdrawal delay
        vm.warp(block.timestamp + stakingContract.withdrawalDelay() + 1);

        vm.expectEmit(true, false, false, true, address(stakingContract));
        emit WithdrawalProcessed(alice, stSOLOBalance, 0);
        //emit WithdrawalProcessed(alice, stakeAmount, 0);

        // Process withdrawal
        stakingContract.processWithdrawal(0);

        // Verify final SOLO balance
        uint256 finalSoloBalance = soloToken.balanceOf(alice);
        assertEq(finalSoloBalance, initialSoloBalance, "Should receive back SOLO equivalent to burned stSOLO");
        //assertEq(finalSoloBalance, initialSoloBalance, "Should receive back original SOLO amount");

        // Verify withdrawal was processed
        (,,,bool[] memory processed) = stakingContract.getPendingWithdrawals(alice);
        assertTrue(processed[0], "Withdrawal should be marked as processed");

        vm.stopPrank();
    }
function test_WithdrawalWithDebug() public {
    // Initial Setup
    uint256 stakeAmount = 100 * 10**18;  // 100 tokens
    
    logHeader("Initial State");
    logEth("Alice's SOLO balance", soloToken.balanceOf(alice));
    logEth("Contract's token per share", stSOLOToken.getTokenPerShare());
    logEth("Total normal shares", stSOLOToken.getTotalNormalShares());
    
    // Phase 1: Staking
    logHeader("Staking Phase");
    vm.startPrank(alice);
    
    // Approve and stake tokens
    soloToken.approve(address(stakingContract), stakeAmount);
    stakingContract.stake(stakeAmount, alice);
    
    // Verify staking success
    uint256 postStakeBalance = stSOLOToken.balanceOf(alice);
    uint256 postStakeShares = stSOLOToken.shareOf(alice);
    
    logEth("Alice's stSOLO balance", postStakeBalance);
    logEth("Alice's shares", postStakeShares);
    
    assertTrue(postStakeBalance > 0, "Staking failed: No stSOLO received");
    assertTrue(postStakeShares > 0, "Staking failed: No shares allocated");
    
    // Phase 2: Pre-Withdrawal Setup
    logHeader("Pre-Withdrawal State");
    
    // Calculate withdrawal amount (using full balance)
    uint256 withdrawAmount = stSOLOToken.balanceOf(alice);
    logEth("Withdrawal amount", withdrawAmount);
    
    // Calculate expected shares to be burned
    uint256 expectedShares = stSOLOToken._amountToShare(withdrawAmount);
    logEth("Expected shares to burn", expectedShares);
    logEth("Actual shares owned", stSOLOToken.shareOf(alice));
    
    // Phase 3: Withdrawal Request
    logHeader("Withdrawal Request");
    
    // Approve stSOLO transfer for withdrawal
    stSOLOToken.approve(address(stakingContract), withdrawAmount);
    
    // Log pre-withdrawal state
    logEth("Pre-withdrawal stSOLO balance", stSOLOToken.balanceOf(alice));
    logBool("StakingContract excluded?", stSOLOToken.excludedFromRebase(address(stakingContract)));
    logBool("Alice excluded?", stSOLOToken.excludedFromRebase(alice));
    
    // Request withdrawal
    stakingContract.requestWithdrawal(withdrawAmount);
    
    // Phase 4: Post-Request Verification
    logHeader("Post-Request State");
    logEth("Alice's remaining stSOLO", stSOLOToken.balanceOf(alice));
    logEth("Contract's stSOLO balance", stSOLOToken.balanceOf(address(stakingContract)));
    
    // Phase 5: Process Withdrawal
    logHeader("Withdrawal Processing");
    
    // Advance time past withdrawal delay
    vm.warp(block.timestamp + stakingContract.withdrawalDelay() + 1);
    
    // Process the withdrawal
    stakingContract.processWithdrawal(0);
    
    // Final state verification
    logHeader("Final State");
    logEth("Alice's final SOLO balance", soloToken.balanceOf(alice));
    logEth("Alice's final shares", stSOLOToken.shareOf(alice));
    logEth("Total remaining shares", stSOLOToken.getTotalNormalShares());
    
    vm.stopPrank();
    
    // Final assertions
    assertEq(
        soloToken.balanceOf(alice),
        INITIAL_AMOUNT,
        "SOLO balance should return to initial amount"
    );
    assertEq(
        stSOLOToken.balanceOf(alice),
        0,
        "stSOLO balance should be zero after withdrawal"
    );
}
    event Staked(address indexed staker, address indexed recipient, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);
}
