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

contract BasicStSOLO is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    uint256 public constant INITIAL_AMOUNT = 1000 * 10 ** 18;
    uint256 public constant INITIAL_REWARD_RATE = 1000; // 10% APR
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

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
        soloToken.transfer(charlie, INITIAL_AMOUNT);
    }

    function test_Alice_Gets_Correct_APY() public {
        // Alice Stakes 100 tokens
        uint amountToStake = 100 ether;
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), amountToStake);
        stakingContract.stake(amountToStake, alice);
        vm.stopPrank();
        vm.assertEq(stSOLOToken.balanceOf(alice), amountToStake);

        vm.warp(block.timestamp + 31536000);
        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            110 ether,
            0.001 ether, // Tolerance of 0.0001 ether
            "Alice's balance is not approximately 110 ether"
        );
    }
    function test_Same_Amounts_APY() public {
        // Alice and Bob Stake Same Amouunt
        uint amountToStake = 100 ether;

        // Alice Stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), amountToStake);
        stakingContract.stake(amountToStake, alice);
        vm.stopPrank();
        vm.assertEq(stSOLOToken.balanceOf(alice), amountToStake);

        // Bob Stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), amountToStake);
        stakingContract.stake(amountToStake, bob);
        vm.stopPrank();
        vm.assertEq(stSOLOToken.balanceOf(bob), amountToStake);

        vm.warp(block.timestamp + 31536000);
        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            110 ether,
            0.001 ether, // Tolerance of 0.0001 ether
            "Alice's balance is not approximately 110 ether"
        );
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            110 ether,
            0.001 ether, // Tolerance of 0.0001 ether
            "Bob's balance is not approximately 110 ether"
        );
    }

    function test_Different_Amounts_APY() public {
        // Alice and Bob Stake Diffrent Amouunt

        // Alice Stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether, alice);
        vm.stopPrank();
        vm.assertEq(stSOLOToken.balanceOf(alice), 100 ether);

        // Bob Stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), 500 ether);
        stakingContract.stake(500 ether, bob);
        vm.stopPrank();
        vm.assertEq(stSOLOToken.balanceOf(bob), 500 ether);

        vm.warp(block.timestamp + 31536000);
        vm.prank(owner);
        stSOLOToken.rebase();

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            110 ether,
            0.001 ether, // Tolerance of 0.0001 ether
            "Alice's balance is not approximately 110 ether"
        );
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            550 ether,
            0.001 ether, // Tolerance of 0.0001 ether
            "Bob's balance is not approximately 110 ether"
        );
    }

    function calculateExpectedBalance(
        uint256 initialStake,
        uint256 tokenPerShare
    ) internal pure returns (uint256) {
        return (initialStake * tokenPerShare) / 1e18;
    }

    function test_Staggered_Staking_Rebase() public {
        uint256 amountToStakeA = 100 ether;

        // Step 1: Alice stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), amountToStakeA);
        stakingContract.stake(amountToStakeA, alice);
        vm.stopPrank();

        // Advance 1 week and rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Capture updated _tokenPerShare
        uint256 updatedTokenPerShare = stSOLOToken.getTokenPerShare();

        // Calculate expected balance for Alice
        uint256 aliceExpectedBalance = calculateExpectedBalance(
            amountToStakeA,
            updatedTokenPerShare
        );

        // Assert Alice's balance matches the expected balance
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            aliceExpectedBalance,
            0.003 ether,
            "Alice's balance is incorrect after first rebase"
        );
    }

    function test_Withdrawal_During_Rebase() public {
        uint256 amountToStakeA = 100 ether;
        uint256 amountToStakeB = 50 ether;

        // Step 1: Alice stakes
        vm.startPrank(alice);
        soloToken.approve(address(stakingContract), amountToStakeA);
        stakingContract.stake(amountToStakeA, alice);
        vm.stopPrank();

        // Step 2: Bob stakes
        vm.startPrank(bob);
        soloToken.approve(address(stakingContract), amountToStakeB);
        stakingContract.stake(amountToStakeB, bob);
        vm.stopPrank();

        // Step 3: Advance 1 week and rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Step 4: Bob requests partial withdrawal
        vm.startPrank(bob);
        uint256 withdrawalAmount = 25 ether;
        stSOLOToken.approve(address(stakingContract), withdrawalAmount);
        stakingContract.requestWithdrawal(withdrawalAmount);
        vm.stopPrank();

        // Step 5: Advance another week and rebase
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        stSOLOToken.rebase();

        // Step 6: Validate balances
        uint256 tokenPerShareAfterSecondRebase = stSOLOToken.getTokenPerShare();
        uint256 aliceExpectedBalanceAfterSecondRebase = calculateExpectedBalance(
                amountToStakeA,
                tokenPerShareAfterSecondRebase
            );

        uint256 remainingSharesBob = stSOLOToken.shareOf(bob);
        // Calculate Bob's balance after second rebase
        uint256 bobExpectedBalanceAfterSecondRebase = (remainingSharesBob *
            stSOLOToken.getTokenPerShare()) / 1e18;
       

        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(alice),
            aliceExpectedBalanceAfterSecondRebase,
            0.003 ether,
            "Alice's balance is incorrect after second rebase"
        );
        // Assert balances
        vm.assertApproxEqAbs(
            stSOLOToken.balanceOf(bob),
            bobExpectedBalanceAfterSecondRebase,
            0.003 ether,
            "Bob's balance is incorrect after second rebase"
        );
    }
}
