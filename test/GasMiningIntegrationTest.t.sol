// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/lib/GasMining.sol";
import "../src/SOLOStaking.sol";
import "../src/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSOLO is ERC20 {
    constructor() ERC20("SOLO Token", "SOLO") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract GasMiningIntegrationTest is Test {
    GasMining public gasMining;
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    MockSOLO public soloToken;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant INITIAL_AMOUNT = 1000 * 10**18;
    uint256 public constant BLOCK_REWARD = 10 * 10**18; // 10 tokens per block
    uint256 public constant EPOCH_DURATION = 100; // 100 blocks per epoch
    uint256 public constant INITIAL_REWARD_RATE = 500; // 5% APR
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    event RewardStaked(address indexed user, address indexed stakingContract, uint256 amount);
    event UserClaimUpdated(address indexed user, uint256[] blocks, uint256[] amounts, uint256 totalAmount);

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Start at block 1
        vm.roll(1);

        // Deploy contracts
        soloToken = new MockSOLO();
        stSOLOToken = new StSOLOToken(INITIAL_REWARD_RATE);
        stakingContract = new SOLOStaking(
            address(soloToken),
            address(stSOLOToken),
            INITIAL_WITHDRAWAL_DELAY
        );
        gasMining = new GasMining(
            address(soloToken),
            BLOCK_REWARD,
            EPOCH_DURATION
        );

        // Setup permissions and initial state
        stSOLOToken.setStakingContract(address(stakingContract));
        
        // Fund accounts and contracts
        soloToken.transfer(address(gasMining), INITIAL_AMOUNT * 10);
        soloToken.transfer(alice, INITIAL_AMOUNT);
        soloToken.transfer(bob, INITIAL_AMOUNT);
        soloToken.transfer(charlie, INITIAL_AMOUNT);

        // Setup approvals for the staking flow
        vm.startPrank(address(gasMining));
        soloToken.approve(address(stakingContract), type(uint256).max);
        vm.stopPrank();

        // Need the staking contract to be able to pull tokens from GasMining
        vm.prank(owner);
        stSOLOToken.setStakingContract(address(stakingContract));
    }

    function test_UpdateAndStakeClaim() public {
        // Start at block 5
        vm.roll(5);

        // Setup claim data
        uint256[] memory blocks = new uint256[](3);
        blocks[0] = 2;
        blocks[1] = 3;
        blocks[2] = 4;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        // Update Alice's claim data
        vm.prank(owner);
        gasMining.updateUserClaim(alice, blocks, amounts);
        
        // Update latest claimable block
        vm.prank(owner);
        gasMining.updateLatestClaimableBlock(5);

        // Verify claim data
        assertEq(gasMining.getPendingClaimAmount(alice), 6 ether, "Incorrect pending amount");

        // Execute stake claim
        vm.prank(alice);
        gasMining.stakeClaim(address(stakingContract));

        // Verify staking results
        assertEq(stSOLOToken.balanceOf(alice), 6 ether, "Incorrect stSOLO balance");
        assertEq(gasMining.getPendingClaimAmount(alice), 0, "Pending amount should be cleared");
    }

    function test_MultipleUserClaimsAndStakes() public {
        // Start at block 10
        vm.roll(10);

        // Setup initial claims for all users
        uint256[] memory blocks = new uint256[](2);
        blocks[0] = 8;
        blocks[1] = 9;

        uint256[] memory aliceAmounts = new uint256[](2);
        aliceAmounts[0] = 1 ether;
        aliceAmounts[1] = 2 ether;

        uint256[] memory bobAmounts = new uint256[](2);
        bobAmounts[0] = 2 ether;
        bobAmounts[1] = 3 ether;

        uint256[] memory charlieAmounts = new uint256[](2);
        charlieAmounts[0] = 3 ether;
        charlieAmounts[1] = 4 ether;

        // Update claims
        vm.startPrank(owner);
        gasMining.updateUserClaim(alice, blocks, aliceAmounts);
        gasMining.updateUserClaim(bob, blocks, bobAmounts);
        gasMining.updateUserClaim(charlie, blocks, charlieAmounts);
        gasMining.updateLatestClaimableBlock(10);
        vm.stopPrank();

        // Users stake their claims
        vm.prank(alice);
        gasMining.stakeClaim(address(stakingContract));
        
        vm.prank(bob);
        gasMining.stakeClaim(address(stakingContract));
        
        vm.prank(charlie);
        gasMining.stakeClaim(address(stakingContract));

        // Verify final states
        assertEq(stSOLOToken.balanceOf(alice), 3 ether, "Incorrect Alice stSOLO balance");
        assertEq(stSOLOToken.balanceOf(bob), 5 ether, "Incorrect Bob stSOLO balance");
        assertEq(stSOLOToken.balanceOf(charlie), 7 ether, "Incorrect Charlie stSOLO balance");
    }

    function test_StakeClaimAndRebase() public {
        vm.roll(5);

        // Setup initial claims
        uint256[] memory blocks = new uint256[](1);
        blocks[0] = 4;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;

        // Setup claims and stake
        vm.startPrank(owner);
        gasMining.updateUserClaim(alice, blocks, amounts);
        gasMining.updateLatestClaimableBlock(5);
        vm.stopPrank();

        vm.prank(alice);
        gasMining.stakeClaim(address(stakingContract));

        uint256 initialBalance = stSOLOToken.balanceOf(alice);
        assertTrue(initialBalance > 0, "Should have non-zero initial balance");

        // Advance time and trigger rebase
        vm.warp(block.timestamp + 30 days);
        stSOLOToken.rebase();

        uint256 finalBalance = stSOLOToken.balanceOf(alice);
        assertTrue(finalBalance > initialBalance, "Balance should increase after rebase");
    }

    function test_UnclaimedDetailsTracking() public {
        vm.roll(10);

        // Setup claim blocks
        uint256[] memory blocks = new uint256[](3);
        blocks[0] = 7;
        blocks[1] = 8;
        blocks[2] = 9;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        // Update claims
        vm.startPrank(owner);
        gasMining.updateUserClaim(alice, blocks, amounts);
        gasMining.updateLatestClaimableBlock(15); // Set future block
        vm.stopPrank();

        // Get unclaimed details
        GasMining.UnclaimedDetails memory details = gasMining.getUnclaimedDetails(alice);

        // Verify tracking
        assertEq(details.pendingAmount, 6 ether, "Incorrect pending amount");
        assertEq(details.missedBlocks, 15 - details.lastClaimedBlock, "Incorrect missed blocks");
        assertTrue(details.lastClaimedBlock < block.number, "Incorrect last claimed block");
    }

    function test_RevertWhen_StakeClaimWithNoRewards() public {
        vm.roll(5);
        vm.prank(owner);
        gasMining.updateLatestClaimableBlock(5);

        vm.prank(alice);
        vm.expectRevert("No pending rewards to claim for the user");
        gasMining.stakeClaim(address(stakingContract));
    }

    function test_RevertWhen_NoNewRewardsToStakeClaim() public {
        // Setup: We need to create a scenario where lastClaimedBlock equals latestClaimableBlock
        vm.roll(5);
        
        // First, set up initial claim and claim it
        uint256[] memory blocks = new uint256[](1);
        blocks[0] = 4;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.startPrank(owner);
        gasMining.updateUserClaim(alice, blocks, amounts);
        gasMining.updateLatestClaimableBlock(5);
        vm.stopPrank();

        // Have Alice claim once to set lastClaimedBlock
        vm.prank(alice);
        gasMining.stakeClaim(address(stakingContract));

        // Now set latest claimable to same as last claimed
        /* Cannot set the same block*/
         /*vm.prank(owner);
        vm.expectRevert("New block number must be greater than the current latest claimable block");
        gasMining.updateLatestClaimableBlock(5);  */ // This should now equal lastClaimedBlock

        // Try to claim again - should revert with no new rewards
        vm.startPrank(alice);
        vm.expectRevert("No new rewards to claim");
        gasMining.stakeClaim(address(stakingContract));
        vm.stopPrank();
    }
}
