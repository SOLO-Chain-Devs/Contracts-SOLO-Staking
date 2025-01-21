// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/upgradeable/SOLOStaking.sol";
import "../src/upgradeable/StSOLOToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/upgradeable/lib/SOLOToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";




/**
 * @title SOLO Staking Basic Test Suite
 * @notice Core test suite for validating basic staking functionality and configuration
 * @dev Implements fundamental test cases for staking, configuration updates, and parameter validation
 */
contract SOLOStakingTest is Test {
    SOLOStaking public stakingContract;
    StSOLOToken public stSOLOToken;
    SOLOToken public soloToken;

    address public owner;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_AMOUNT = 1000 * 10**18;
    uint256 public constant INITIAL_TOKENS_PER_YEAR_RATE = 100_000 ether; 
    uint256 public constant INITIAL_WITHDRAWAL_DELAY = 7 days;

    /**
     * @notice Initializes the test environment with necessary contracts and test accounts
     * @dev Sets up staking contract, tokens, and initial test state including:
     *      - Deploying mock SOLO token
     *      - Deploying stSOLO token with 5% initial reward rate
     *      - Configuring staking contract with 7-day withdrawal delay
     *      - Distributing initial tokens to test accounts
     *      - Performing initial stake to establish baseline state
     */
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

    // Fund accounts and initial stake
    soloToken.mintTo(owner, 1_000_000 ether);
    soloToken.transfer(alice, INITIAL_AMOUNT);
    soloToken.transfer(bob, INITIAL_AMOUNT);

    vm.startPrank(alice);
    soloToken.approve(address(stakingContract), 1 ether);
    stakingContract.stake(1 ether, alice);
    vm.stopPrank();
    }

    /**
     * @notice Verifies the initial setup of the staking system
     * @dev Checks contract addresses, withdrawal delay, and reward rate
     */
    function test_InitialSetup() public view {
        assertEq(address(stakingContract.soloToken()), address(soloToken));
        assertEq(address(stakingContract.stSOLOToken()), address(stSOLOToken));
        assertEq(stakingContract.withdrawalDelay(), INITIAL_WITHDRAWAL_DELAY);
        assertEq(stSOLOToken.tokensPerYear(), INITIAL_TOKENS_PER_YEAR_RATE);
    }

    /**
     * @notice Tests setting an excessive reward rate
     * @dev Verifies that setting a reward rate above 30% APR reverts
     */
    function test_RevertWhen_SettingExcessiveRewardRate() public {
        uint256 tooHighRate = stSOLOToken.MAX_TOKENS_PER_YEAR() + 1;  // Same value as MAX_TOKENS_PER_YEAR
        vm.expectRevert("TokensPerYear inflation exceeds max");
        vm.prank(owner);
        stSOLOToken.setRewardTokensPerYear(tooHighRate);
    }

    /**
     * @notice Tests setting an excessive withdrawal delay
     * @dev Verifies that setting a delay above 30 days reverts
     */
    function test_RevertWhen_SettingExcessiveWithdrawalDelay() public {
        uint256 tooLongDelay = 31 days;
        vm.expectRevert("Invalid delay");
        vm.prank(owner);
        stakingContract.setWithdrawalDelay(tooLongDelay);
    }

    /**
     * @notice Tests staking to zero address
     * @dev Verifies that attempting to stake to address(0) reverts
     */
    function test_RevertWhen_StakingToZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        vm.prank(alice);
        stakingContract.stake(100 * 10**18, address(0));
    }

    /**
     * @notice Tests staking zero amount
     * @dev Verifies that attempting to stake 0 tokens reverts
     */
    function test_RevertWhen_StakingZero() public {
        vm.expectRevert("Cannot stake 0");
        vm.prank(alice);
        stakingContract.stake(0, alice);
    }

    /**
     * @notice Tests updating reward rate
     * @dev Verifies reward rate can be updated within allowed range
     */
    function test_UpdateRewardRate() public {
        uint256 newRate = 1000; 
        vm.prank(owner);
        vm.warp(block.timestamp + 1 days); // need to warp 1 day so that rebase can occur
        stSOLOToken.setRewardTokensPerYear(newRate);
        assertEq(stSOLOToken.tokensPerYear(), newRate);
    }

    /**
     * @notice Tests updating withdrawal delay
     * @dev Verifies withdrawal delay can be updated within allowed range
     */
    function test_UpdateWithdrawalDelay() public {
        uint256 newDelay = 14 days;
        vm.prank(owner);
        stakingContract.setWithdrawalDelay(newDelay);
        assertEq(stakingContract.withdrawalDelay(), newDelay);
    }
}
