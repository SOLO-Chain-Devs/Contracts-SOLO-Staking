// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/mock/SOLO.sol";
import "../src/stakedSOLO.sol";
import "../src/restakedSOLO.sol";

contract SOLOTest is Test {
    SOLO public solo;
    StakedSOLO public sSolo;
    RestakedSOLO public rsSolo;
    
    address public alice = address(1);
    address public bob = address(2);
    uint256 public initialSupply = 1000000e18;

    function setUp() public {
        // Deploy contracts
        solo = new SOLO(initialSupply);
        sSolo = new StakedSOLO(address(solo));
        rsSolo = new RestakedSOLO(address(sSolo));

        // Give some SOLO to test addresses
        solo.transfer(alice, 10000e18);
        solo.transfer(bob, 10000e18);
    }

    // Basic unit tests for SOLO
    function testSOLOInitialSupply() public {
        assertEq(solo.totalSupply(), initialSupply);
    }

    function testSOLOTransfer() public {
        uint256 balanceBefore = solo.balanceOf(bob);
        vm.prank(alice);
        solo.transfer(bob, 1000e18);
        assertEq(solo.balanceOf(bob), balanceBefore + 1000e18);
    }

    // StakedSOLO Tests
    function testStakeSOLO() public {
        vm.startPrank(alice);
        uint256 stakeAmount = 1000e18;
        solo.approve(address(sSolo), stakeAmount);
        sSolo.deposit(stakeAmount);
        
        assertEq(sSolo.balanceOf(alice), stakeAmount);
        assertEq(solo.balanceOf(address(sSolo)), stakeAmount);
        vm.stopPrank();
    }

    function testStakeSOLOTo() public {
        vm.startPrank(alice);
        uint256 stakeAmount = 1000e18;
        solo.approve(address(sSolo), stakeAmount);
        sSolo.depositTo(bob, stakeAmount);
        
        assertEq(sSolo.balanceOf(bob), stakeAmount);
        assertEq(solo.balanceOf(address(sSolo)), stakeAmount);
        vm.stopPrank();
    }

    function testUnstakeSOLO() public {
        vm.startPrank(alice);
        uint256 stakeAmount = 1000e18;
        solo.approve(address(sSolo), stakeAmount);
        sSolo.deposit(stakeAmount);
        
        uint256 soloBalanceBefore = solo.balanceOf(alice);
        sSolo.withdraw(stakeAmount);
        
        assertEq(sSolo.balanceOf(alice), 0);
        assertEq(solo.balanceOf(alice), soloBalanceBefore + stakeAmount);
        vm.stopPrank();
    }

    // RestakedSOLO Tests
    function testRestakeSOLO() public {
        vm.startPrank(alice);
        uint256 stakeAmount = 1000e18;
        
        // First stake SOLO
        solo.approve(address(sSolo), stakeAmount);
        sSolo.deposit(stakeAmount);
        
        // Then restake sSOLO
        sSolo.approve(address(rsSolo), stakeAmount);
        rsSolo.deposit(stakeAmount);
        
        assertEq(rsSolo.balanceOf(alice), stakeAmount);
        assertEq(sSolo.balanceOf(address(rsSolo)), stakeAmount);
        vm.stopPrank();
    }

    function testUnrestakeSOLO() public {
        vm.startPrank(alice);
        uint256 stakeAmount = 1000e18;
        
        // Setup staking
        solo.approve(address(sSolo), stakeAmount);
        sSolo.deposit(stakeAmount);
        sSolo.approve(address(rsSolo), stakeAmount);
        rsSolo.deposit(stakeAmount);
        
        // Test unstaking
        uint256 sSOLOBalanceBefore = sSolo.balanceOf(alice);
        rsSolo.withdraw(stakeAmount);
        
        assertEq(rsSolo.balanceOf(alice), 0);
        assertEq(sSolo.balanceOf(alice), sSOLOBalanceBefore + stakeAmount);
        vm.stopPrank();
    }

    // Failure cases
    function testFailStakeWithoutApproval() public {
        vm.prank(alice);
        sSolo.deposit(1000e18);
    }

    function testFailRestakeWithoutApproval() public {
        vm.startPrank(alice);
        solo.approve(address(sSolo), 1000e18);
        sSolo.deposit(1000e18);
        rsSolo.deposit(1000e18); // Should fail - no approval
        vm.stopPrank();
    }

    function testFailWithdrawTooMuch() public {
        vm.startPrank(alice);
        solo.approve(address(sSolo), 1000e18);
        sSolo.deposit(1000e18);
        sSolo.withdraw(2000e18); // Should fail - insufficient balance
        vm.stopPrank();
    }

    // Fuzz tests
    function testFuzz_StakeUnstake(uint256 amount) public {
        // Bound the amount to something reasonable and non-zero
        amount = bound(amount, 1, 1000000e18);
        
        vm.startPrank(alice);
        solo.approve(address(sSolo), amount);
        
        uint256 soloBalanceBefore = solo.balanceOf(alice);
        sSolo.deposit(amount);
        sSolo.withdraw(amount);
        
        assertEq(solo.balanceOf(alice), soloBalanceBefore);
        vm.stopPrank();
    }

    function testFuzz_StakeRestakeUnstake(uint256 amount) public {
        // Bound the amount to something reasonable and non-zero
        amount = bound(amount, 1, 1000000e18);
        
        vm.startPrank(alice);
        
        // Initial setup
        solo.approve(address(sSolo), amount);
        sSolo.deposit(amount);
        sSolo.approve(address(rsSolo), amount);
        
        uint256 ssoloBalanceBefore = sSolo.balanceOf(alice);
        
        // Restake and unstake
        rsSolo.deposit(amount);
        rsSolo.withdraw(amount);
        
        assertEq(sSolo.balanceOf(alice), ssoloBalanceBefore);
        vm.stopPrank();
    }

    function testFuzz_MultipleStakes(uint256[] calldata amounts) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10);
        
        uint256 totalAmount = 0;
        vm.startPrank(alice);
        
        for(uint i = 0; i < amounts.length; i++) {
            uint256 amount = bound(amounts[i], 1, 1000000e18);
            totalAmount += amount;
            
            solo.approve(address(sSolo), amount);
            sSolo.deposit(amount);
        }
        
        assertEq(sSolo.balanceOf(alice), totalAmount);
        vm.stopPrank();
    }
}
