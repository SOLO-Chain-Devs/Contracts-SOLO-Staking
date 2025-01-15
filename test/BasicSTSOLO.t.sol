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

    // Configuration constants
    uint256 public constant INITIAL_AMOUNT = 1000 * 10 ** 18;
    uint256 public rewardRate; // APR in basis points (100 = 1%)
    uint256 public withdrawalDelay;
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public constant PRECISION = 0.001 ether; // Tolerance for approximate equality checks

    // Test parameters
    uint256 public baseStakeAmount;
    uint256 public largeStakeAmount;

    function setUp() public {
        // Initialize accounts
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Set configurable parameters
        rewardRate = 100000; // 10% APR by default
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
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);
    }

    /**
     * @notice Tests if a user receives correct APY after one year
     * @dev Verifies that staking rewards are calculated correctly based on the reward rate
     */
    function test_User_Gets_Correct_APY() public {
        // Calculate expected balance after one year
        uint256 expectedBalance = baseStakeAmount + (baseStakeAmount * rewardRate / 10000);

        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();
        
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
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
        // Calculate expected balance after one year
        uint256 expectedBalance = baseStakeAmount + (baseStakeAmount * rewardRate / 10000);

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

        vm.warp(block.timestamp + SECONDS_PER_YEAR);
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
        // Calculate expected balances
        uint256 expectedSmallBalance = baseStakeAmount + (baseStakeAmount * rewardRate / 10000);
        uint256 expectedLargeBalance = largeStakeAmount + (largeStakeAmount * rewardRate / 10000);

        // Alice stakes base amount
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), baseStakeAmount);
        stakingContract.stake(baseStakeAmount, alice);
        vm.stopPrank();

        // Bob stakes large amount
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), largeStakeAmount);
        stakingContract.stake(largeStakeAmount, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + SECONDS_PER_YEAR);
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
}
