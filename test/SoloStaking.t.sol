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

contract SOLOStakingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    address public owner;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_AMOUNT = 1000 * 10**18;
    uint256 public constant INITIAL_REWARD_RATE = 500; // 5% APR
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    event Staked(address indexed staker, address indexed recipient, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);

    function setUp() public {
        // Setup accounts
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy contracts
        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(INITIAL_REWARD_RATE);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            INITIAL_WITHDRAWAL_DELAY
        );

        // Configure stSOLO token
        stSOLOToken.setStakingContract(address(stakingContract));

        // First distribute tokens to test accounts
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);

        // Now perform initial stake with Alice
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), 1 ether);
        stakingContract.stake(1 ether, alice);
        vm.stopPrank();
    }

    function test_InitialSetup() public {
        assertEq(address(stakingContract.soloToken()), address(soloToken));
        assertEq(address(stakingContract.stSOLOToken()), address(stSOLOToken));
        assertEq(stakingContract.withdrawalDelay(), INITIAL_WITHDRAWAL_DELAY);
        assertEq(stSOLOToken.rewardRate(), INITIAL_REWARD_RATE);
    }

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

    function test_StakeForOther() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        assertApproxEqRel(stSOLOToken.balanceOf(bob), stakeAmount, 1e16);
        assertEq(soloToken.balanceOf(address(stakingContract)), stakeAmount + 1);
    }

    function test_RevertWhen_StakingZero() public {
        vm.expectRevert("Cannot stake 0");
        vm.prank(alice);
        stakingContract.stake(0, alice);
    }

    function test_RevertWhen_StakingToZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        vm.prank(alice);
        stakingContract.stake(100 * 10**18, address(0));
    }

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

    function test_Rebase() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Stake tokens
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        // Wait for a year
        vm.warp(block.timestamp + 365 days);

        // Trigger rebase
        uint256 rebaseAmount = stSOLOToken.rebase();
        
        // Calculate expected rewards (5% APR)
        uint256 expectedRewards = (stakeAmount * INITIAL_REWARD_RATE) / 10000;
        assertApproxEqRel(rebaseAmount, expectedRewards, 1e16);
        
        // Check increased balance
        assertGt(stSOLOToken.balanceOf(alice), stakeAmount);
    }

    function test_ExcludeFromRebase() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Stake tokens for both users
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount, bob);
        vm.stopPrank();

        // Exclude Bob from rebases
        vm.prank(owner);
        stSOLOToken.setExcluded(bob, true);

        // Wait for a year and rebase
        vm.warp(block.timestamp + 365 days);
        stSOLOToken.rebase();

        // Check that only Alice's balance increased
        assertGt(stSOLOToken.balanceOf(alice), stakeAmount);
        assertEq(stSOLOToken.balanceOf(bob), stakeAmount);
    }

    function test_UpdateRewardRate() public {
        uint256 newRate = 1000; // 10% APR
        
        vm.prank(owner);
        stSOLOToken.setRewardRate(newRate);
        
        assertEq(stSOLOToken.rewardRate(), newRate);
    }

    function test_RevertWhen_SettingExcessiveRewardRate() public {
        uint256 tooHighRate = 3100; // 31% APR
        
        vm.expectRevert("Rate too high");
        vm.prank(owner);
        stSOLOToken.setRewardRate(tooHighRate);
    }

    function test_UpdateWithdrawalDelay() public {
        uint256 newDelay = 14 days;
        
        vm.prank(owner);
        stakingContract.setWithdrawalDelay(newDelay);
        
        assertEq(stakingContract.withdrawalDelay(), newDelay);
    }

    function test_RevertWhen_SettingExcessiveWithdrawalDelay() public {
        uint256 tooLongDelay = 31 days;
        
        vm.expectRevert("Invalid delay");
        vm.prank(owner);
        stakingContract.setWithdrawalDelay(tooLongDelay);
    }
}
