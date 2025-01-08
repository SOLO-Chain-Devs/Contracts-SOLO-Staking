// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/StdUtils.sol";  // This provides string conversion capabilities
import "forge-std/Test.sol";
import "../src/SOLOStaking.sol";
import "../src/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
    * @title Advanced SOLO Staking Test Suite
* @notice Comprehensive test suite exploring complex staking scenarios
* @dev Utilizes Foundry's fuzzing and advanced testing capabilities
*/
contract AdvancedSOLOStakingTest is Test {
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

    /**
        * @notice Sets up the testing environment before each test
    * @dev Deploys contracts and distributes initial tokens
    */
    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
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

        // Distribute tokens to test users
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);
    }

    /**
        * @notice Fuzz test for multiple user staking
    * @param stakeAmountA Amount for first user to stake
        * @param stakeAmountB Amount for second user to stake
    function testFuzz_MultiUserStaking(
        uint96 stakeAmountA, 
        uint96 stakeAmountB
    ) public {
            vm.assume(stakeAmountA >= 1 ether && stakeAmountA <= INITIAL_AMOUNT / 10);
    vm.assume(stakeAmountB >= 1 ether && stakeAmountB <= INITIAL_AMOUNT / 10);
        // Alice stakes first
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmountA);
        stakingContract.stake(stakeAmountA, alice);
        vm.stopPrank();

        // Bob stakes second
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmountB);
        stakingContract.stake(stakeAmountB, bob);
        vm.stopPrank();

        // Verify balances
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmountA + stakeAmountB);
        assertApproxEqRel(stSOLOToken.balanceOf(alice), stakeAmountA, 1e16);
        assertApproxEqRel(stSOLOToken.balanceOf(bob), stakeAmountB, 1e16);
    }
    */

    /**
        * @notice Tests complex withdrawal scenarios with multiple users
    * @dev Verifies withdrawal mechanics under different conditions
    */
    function test_ComplexRebaseExclusionOne() public {
        uint256 stakeAmount = 1000 * 10**18;

        // More explicit setup and validation
        for (uint i = 0; i < 3; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            soloToken.transfer(user, stakeAmount * 2);
            
            vm.startPrank(user);
            soloToken.approve(address(stakingContract), stakeAmount);
            stakingContract.stake(stakeAmount, user);
            vm.stopPrank();
        }

        // Selective exclusion logic remains similar
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);

        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // More nuanced balance assertions
        uint256 aliceBalance = stSOLOToken.balanceOf(alice);
        assertTrue(aliceBalance > stakeAmount, "Alice's balance should increase");
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount, "Excluded user balance unchanged");
    }

    /**
        * @notice Fuzz test for reward rate updates
    * @param newRewardRate New reward rate to test
    function testFuzz_RewardRateUpdate(uint16 newRewardRate) public {
        vm.assume(newRewardRate > 0 && newRewardRate <= 3000); // Max 30% APR

        vm.prank(owner);
        stSOLOToken.setRewardRate(newRewardRate);

        assertEq(stSOLOToken.rewardRate(), newRewardRate);
    }
    */

    /**
        * @notice Tests edge case of staking zero amount
    */
    function test_RevertWhen_StakingZeroAmount() public {
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), 0);

        vm.expectRevert("Cannot stake 0");
        stakingContract.stake(0, alice);
        vm.stopPrank();
    }

    /**
        * @notice Comprehensive exclusion and rebase test
    * @dev Verifies complex rebase behavior with multiple excluded addresses
    */
    function test_ComplexRebaseExclusion() public {
        uint256 stakeAmount = 1000 * 10**18;

        // Stake for multiple users
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        vm.startPrank(charlie);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, charlie);
        vm.stopPrank();

        // Exclude Bob and Charlie from rebasing
        vm.startPrank(owner);
        stSOLOToken.setExcluded(bob, true);
        stSOLOToken.setExcluded(charlie, true);
        vm.stopPrank();

        // Warp time and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // Verify only Alice's balance increased
        assertTrue(stSOLOToken.balanceOf(alice) > stakeAmount);
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount);
        assertEq(stSOLOToken.balanceOf(charlie), stakeAmount);
    }

    /**
        * @notice Tests withdrawal request limit and gas efficiency
    * @param numberOfRequests Number of withdrawal requests to simulate
    function testFuzz_MultipleWithdrawalRequests(uint8 numberOfRequests) public {
            vm.assume(numberOfRequests >= 1 && numberOfRequests <= 5);

        uint256 stakeAmount = 100 * 10**18;

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount * numberOfRequests);

        // Stake and create multiple withdrawal requests
        for (uint256 i = 0; i < numberOfRequests; i++) {
            stakingContract.stake(stakeAmount, alice);
            stSOLOToken.approve(address(stakingContract), stakeAmount);
            stakingContract.requestWithdrawal(stakeAmount);
        }
        vm.stopPrank();

        // Verify withdrawal requests
        (uint256[] memory soloAmounts,,, bool[] memory processed) = 
            stakingContract.getPendingWithdrawals(alice);

        assertEq(soloAmounts.length, numberOfRequests);
        assertEq(processed.length, numberOfRequests);
    }
    */
    /**
        * @notice Comprehensive multi-user staking and withdrawal simulation
    * @dev Tests interaction of 6 users with varied staking and withdrawal patterns
    */
    function test_SixUserStakingAndWithdrawalScenario() public {
        address[] memory users = new address[](6);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");
        users[3] = makeAddr("user4");
        users[4] = makeAddr("user5");
        users[5] = makeAddr("user6");

        uint256[] memory stakeAmounts = new uint256[](6);
        stakeAmounts[0] = 100 * 10**18;
        stakeAmounts[1] = 250 * 10**18;
        stakeAmounts[2] = 500 * 10**18;
        stakeAmounts[3] = 75 * 10**18;
        stakeAmounts[4] = 200 * 10**18;
        stakeAmounts[5] = 150 * 10**18;

        // Distribute tokens and stake
        for (uint i = 0; i < users.length; i++) {
            soloToken.transfer(users[i], stakeAmounts[i] * 2);

            vm.startPrank(users[i]);
            soloToken.approve(address(stakingContract), stakeAmounts[i]);
            stakingContract.stake(stakeAmounts[i], users[i]);
            vm.stopPrank();
        }

        // Verify initial stakes
        for (uint i = 0; i < users.length; i++) {
            assertApproxEqRel(
                stSOLOToken.balanceOf(users[i]), 
                stakeAmounts[i], 
                1e16
            );
        }

        // Simulate partial withdrawals for some users
        vm.startPrank(users[1]);
        uint256 partialWithdrawalAmount = stakeAmounts[1] / 2;
        stSOLOToken.approve(address(stakingContract), partialWithdrawalAmount);
        stakingContract.requestWithdrawal(partialWithdrawalAmount);
        vm.stopPrank();

        // Simulate full withdrawal for another user
        vm.startPrank(users[3]);
        stSOLOToken.approve(address(stakingContract), stakeAmounts[3]);
        stakingContract.requestWithdrawal(stakeAmounts[3]);
        vm.stopPrank();

        // Warp time to allow withdrawals
        vm.warp(block.timestamp + INITIAL_WITHDRAWAL_DELAY + 1);

        // Process withdrawals
        vm.startPrank(users[1]);
        stakingContract.processWithdrawal(0);
        vm.stopPrank();

        vm.startPrank(users[3]);
        stakingContract.processWithdrawal(0);
        vm.stopPrank();

        // Additional verifications
        assertApproxEqRel(
            stSOLOToken.balanceOf(users[1]), 
            stakeAmounts[1] / 2, 
            1e16
        );
        assertEq(stSOLOToken.balanceOf(users[3]), 0);
    }

    /**
        * @notice Stress test multiple concurrent exclusions and rebasing
    * @dev Validates system behavior with multiple users and selective exclusions
    */
    function test_ComplexMultiUserRebaseAndExclusion() public {
        address[] memory users = new address[](6);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");
        users[3] = makeAddr("user4");
        users[4] = makeAddr("user5");
        users[5] = makeAddr("user6");

        uint256 baseStakeAmount = 200 * 10**18;

        // Distribute and stake tokens
        for (uint i = 0; i < users.length; i++) {
            soloToken.transfer(users[i], baseStakeAmount * 2);

            vm.startPrank(users[i]);
            soloToken.approve(address(stakingContract), baseStakeAmount);
            stakingContract.stake(baseStakeAmount, users[i]);
            vm.stopPrank();
        }

        // Selectively exclude users
        vm.startPrank(owner);
        stSOLOToken.setExcluded(users[2], true);  // Exclude user3
        stSOLOToken.setExcluded(users[4], true);  // Exclude user5
        vm.stopPrank();

        // Advance time and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // Verify rebase effects
        for (uint i = 0; i < users.length; i++) {
            if (i == 2 || i == 4) {
                // Excluded users should have unchanged balance
                assertEq(stSOLOToken.balanceOf(users[i]), baseStakeAmount);
            } else {
                // Non-excluded users should have increased balance
                assertTrue(stSOLOToken.balanceOf(users[i]) > baseStakeAmount);
            }
        }
    }
}

// Mock token contract for testing
contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 10_000_000 * 10**decimals());
    }
}
