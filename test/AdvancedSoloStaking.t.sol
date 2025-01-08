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


    function test_ExcludeFromRebasePreExcluded() public {
        uint256 stakeAmount = 100 * 10**18;
        logHeader("test_ExcludeFromRebasePreExcluded");

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

    /**
        * @notice Tests the rebasing mechanism with excluded addresses
    * @dev Verifies that excluded addresses don't receive rebase rewards while others do
        */
    function test_ExcludeFromRebasePostExcluded() public {
        logHeader("test_ExcludeFromRebasePostExcluded");
        uint256 stakeAmount = 100 * 10**18;

        // Stage 1: Initial Staking
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        console.log("\nAfter Alice stakes:");
        logEth("Alice initial shares:",stSOLOToken.shareOf(alice));
        logEth("Alice initial shares:", stSOLOToken.shareOf(alice));
        logEth("Alice initial balance:", stSOLOToken.balanceOf(alice));
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        logMinor("\nAfter Bob stakes:");
        logEth("Bob initial shares:",stSOLOToken.shareOf(bob));
        logEth("Bob initial balance:",stSOLOToken.balanceOf(bob));
        vm.stopPrank();

        // Stage 2: Pre-Exclusion State
        console.log("\nPre-exclusion state:");
        logEth("Total supply:", stSOLOToken.totalSupply());
        logEth("Total shares:", stSOLOToken.totalShares());
        uint256 aliceBalanceBeforeExclusion = stSOLOToken.balanceOf(alice);
        //uint256 bobBalanceBeforeExclusion = stSOLOToken.balanceOf(bob);

        // Stage 3: Apply Exclusion
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);
        console.log("\nPost-exclusion state:");
        logBool("Is Bob excluded:", stSOLOToken.excludedFromRebase(bob));
        logEth("Excluded amount:", stSOLOToken.calculateExcludedAmount());

        // Stage 4: First Rebase Period
        vm.warp(block.timestamp + 365 days);
        uint256 rebaseAmount = stSOLOToken.rebase();
        console.log("\nAfter first rebase:");
        logEth("Rebase amount:", rebaseAmount);

        // Stage 5: Final State Validation
        console.log("\nFinal states:");
        logEth("Alice final shares:", stSOLOToken.shareOf(alice));
        logEth("Alice final balance:", stSOLOToken.balanceOf(alice));
        logEth("Bob final shares:", stSOLOToken.shareOf(bob));
        logEth("Bob final balance:", stSOLOToken.balanceOf(bob));
        logEth("Total supply after:", stSOLOToken.totalSupply());

        // Assertions
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Bob's balance should remain at stake amount");
        assertTrue(
            stSOLOToken.balanceOf(alice) > aliceBalanceBeforeExclusion,
            "Alice's balance should increase after rebase"
        );
        logEth("Alice's balance increase:", 
            stSOLOToken.balanceOf(alice) - aliceBalanceBeforeExclusion);
    }
    

    function test_ExcludeFromRebaseYieldPostExcluded(uint256 _daysToPass) public {
        uint256 stakeAmount = 100 * 10**18;
        
        uint256 daysToPass = bound(_daysToPass, 1, 365);
        
        // For clarity, let's calculate expected yields upfront
        uint256 yearlyRate = INITIAL_REWARD_RATE; 
        uint256 expectedDailyYield = (yearlyRate * 1e18) / (365 * 10000); 
        
        logHeader("test_ExcludeFromRebasePostExcluded");
        logMinor("Test Parameters:");
        logEth("Days to pass:", daysToPass);
        logEth("Yearly APR (basis points):", yearlyRate);
        logEth("Expected daily yield %:", expectedDailyYield);

        // Original staking logic for Alice and Bob...
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        // Record pre-exclusion states
        uint256 aliceBalanceBefore = stSOLOToken.balanceOf(alice);
        uint256 bobBalanceBefore = stSOLOToken.balanceOf(bob);

        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);

        // Warp time and rebase
        vm.warp(block.timestamp + (daysToPass * 1 days));
        
        logMajor("Pre-rebase State:");
        logEth("Time elapsed (days):", daysToPass);
        logEth("Alice initial balance:", aliceBalanceBefore);
        logEth("Bob initial balance:", bobBalanceBefore);

        uint256 rebaseAmount = stSOLOToken.rebase();
        
        uint256 aliceBalanceAfter = stSOLOToken.balanceOf(alice);
        uint256 actualYieldAmount = aliceBalanceAfter - aliceBalanceBefore;
        uint256 actualYieldPercentage = (actualYieldAmount * 1e18) / aliceBalanceBefore;
        
        logMajor("Post-rebase Results:");
        logEth("Rebase amount:", rebaseAmount);
        logEth("Alice new balance:", aliceBalanceAfter);
        logEth("Actual yield amount:", actualYieldAmount);
        logEth("Actual yield percentage:", actualYieldPercentage);
        
        // Calculate expected yield for comparison
        uint256 expectedYield = (aliceBalanceBefore * daysToPass * yearlyRate) / (365 * 10000);
        logEth("Expected yield amount:", expectedYield);
        
        // Original assertions plus yield validation
        assertEq(stSOLOToken.balanceOf(bob), bobBalanceBefore, "Bob's balance should remain fixed");
        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice's balance should increase after rebase");
        assertApproxEqRel(actualYieldAmount, expectedYield, 1e16, "Yield should match expected amount within 1%");
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
