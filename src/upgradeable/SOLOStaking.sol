/**
 * @title SOLO Staking Contract
 * @author Original contract enhanced with NatSpec
 * @notice This contract manages the staking of SOLO tokens and minting of stSOLO tokens
 * @dev Implements staking mechanics with withdrawal delay and request management
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./StSOLOToken.sol";

/**
 * @title SOLOStaking
 * @notice A staking contract that allows users to stake SOLO tokens and receive stSOLO tokens
 * @dev Inherits from Ownable and ReentrancyGuard for secure management of staking operations
 */
/**
 * @title Upgradeable SOLOStaking
 * @notice A staking contract that allows users to stake SOLO tokens and receive stSOLO tokens
 * @dev Inherits from OwnableUpgradeable, UUPSUpgradeable, and ReentrancyGuardUpgradeable
 */
contract SOLOStaking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    // State variables
    IERC20 public soloToken;
    StSOLOToken public stSOLOToken;
    uint256 public withdrawalDelay;

    uint256 public constant MIN_WITHDRAWAL_DELAY = 0 days;
    uint256 public constant MAX_WITHDRAWAL_DELAY = 30 days;

    struct WithdrawalRequest {
        uint256 soloAmount;
        uint256 stSOLOAmount;
        uint256 requestTime;
        bool processed;
    }

    mapping(address => WithdrawalRequest[]) public withdrawalRequests;

    event Staked(address indexed staker, address indexed recipient, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer function for the contract
     * @dev Replaces constructor for upgradeable contracts
     * @param _soloToken Address of the SOLO token contract
     * @param _stSOLOToken Address of the stSOLO token contract
     * @param _initialWithdrawalDelay Initial delay period for withdrawals
     */
    function initialize(
        address _soloToken,
        address _stSOLOToken,
        uint256 _initialWithdrawalDelay
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(
            _initialWithdrawalDelay >= MIN_WITHDRAWAL_DELAY &&
            _initialWithdrawalDelay <= MAX_WITHDRAWAL_DELAY,
            "Invalid delay"
        );

        soloToken = IERC20(_soloToken);
        stSOLOToken = StSOLOToken(_stSOLOToken);
        withdrawalDelay = _initialWithdrawalDelay;
    }

    /**
     * @notice Updates the withdrawal delay period
     * @dev Can only be called by owner, enforces minimum and maximum delay limits
     * @param _newDelay New delay period in seconds
     */
    function setWithdrawalDelay(uint256 _newDelay) external onlyOwner {
        require(_newDelay >= MIN_WITHDRAWAL_DELAY && 
                _newDelay <= MAX_WITHDRAWAL_DELAY, 
                "Invalid delay");
        emit WithdrawalDelayUpdated(withdrawalDelay, _newDelay);
        withdrawalDelay = _newDelay;
    }

    /**
     * @notice Stakes SOLO tokens and mints stSOLO tokens
     * @dev Transfers SOLO tokens from user and mints equivalent stSOLO tokens
     * @param _amount Amount of SOLO tokens to stake
     * @param _recipient Address to receive the stSOLO tokens
     */
    function stake(uint256 _amount, address _recipient) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        require(_recipient != address(0), "Invalid recipient");
        // Prevent staking directly to the staking contract
        require(_recipient != address(this), "Cannot stake to contract");
        
        // Transfer SOLO tokens from the staker
        require(soloToken.transferFrom(msg.sender, address(this), _amount),
                "SOLO transfer failed");

        // Mint stSOLO tokens to the specified recipient
        stSOLOToken.mint(_recipient, _amount);
        
        emit Staked(msg.sender, _recipient, _amount);
    }

    /**
     * @notice Initiates a withdrawal request for stSOLO tokens
     * @dev Burns stSOLO tokens and creates a withdrawal request for SOLO tokens
     * @param stSOLOAmount Amount of stSOLO tokens to withdraw
     */
    function requestWithdrawal(uint256 stSOLOAmount) external nonReentrant {
        require(stSOLOAmount > 0, "Cannot withdraw 0");
        require(stSOLOToken.balanceOf(msg.sender) >= stSOLOAmount, 
                "Insufficient stSOLO balance");
        require(stSOLOToken.allowance(msg.sender, address(this)) >= stSOLOAmount,
                "Insufficient allowance");

        // Calculate corresponding SOLO amount based on current share rate
        uint256 soloAmount = stSOLOAmount; // 1:1 for initial implementation

        // Create withdrawal request
        uint256 requestId = withdrawalRequests[msg.sender].length;
        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            soloAmount: soloAmount,
            stSOLOAmount: stSOLOAmount,
            requestTime: block.timestamp,
            processed: false
        }));

        // Transfer and burn stSOLO tokens immediately
        // TODO not sure if there is a use to keep SOLO in supply and only burn later
        // Commenting this out because I was insane when I wrote this. WTF ?
        //require(stSOLOToken.transferFrom(msg.sender, address(this), stSOLOAmount),"stSOLO transfer failed");
        //stSOLOToken.burn(address(this), stSOLOAmount);
        stSOLOToken.burn(msg.sender, stSOLOAmount);

        emit WithdrawalRequested(msg.sender, stSOLOAmount, soloAmount, requestId);
    }

    /**
     * @notice Processes a pending withdrawal request
     * @dev Transfers SOLO tokens back to user after delay period
     * @param _requestId ID of the withdrawal request to process
     */
    function processWithdrawal(uint256 _requestId) external nonReentrant {
        require(_requestId < withdrawalRequests[msg.sender].length, 
                "Invalid request ID");
        
        WithdrawalRequest storage request = withdrawalRequests[msg.sender][_requestId];
        require(!request.processed, "Already processed");
        require(block.timestamp >= request.requestTime + withdrawalDelay, 
                "Withdrawal delay not met");

        request.processed = true;
        
        // Transfer SOLO tokens back to user
        require(soloToken.transfer(msg.sender, request.soloAmount),
                "SOLO transfer failed");

        emit WithdrawalProcessed(msg.sender, request.soloAmount, _requestId);
    }

    /**
     * @notice Retrieves all withdrawal requests for a user
     * @dev Returns arrays of withdrawal request details
     * @param _user Address of the user
     * @return soloAmounts Array of SOLO token amounts
     * @return stSOLOAmounts Array of stSOLO token amounts
     * @return requestTimes Array of request timestamps
     * @return processed Array of processing status flags
     */
    function getPendingWithdrawals(address _user) 
        external 
        view 
        returns (
            uint256[] memory soloAmounts,
            uint256[] memory stSOLOAmounts,
            uint256[] memory requestTimes,
            bool[] memory processed
        ) 
    {
        WithdrawalRequest[] storage requests = withdrawalRequests[_user];
        soloAmounts = new uint256[](requests.length);
        stSOLOAmounts = new uint256[](requests.length);
        requestTimes = new uint256[](requests.length);
        processed = new bool[](requests.length);

        for (uint256 i = 0; i < requests.length; i++) {
            soloAmounts[i] = requests[i].soloAmount;
            stSOLOAmounts[i] = requests[i].stSOLOAmount;
            requestTimes[i] = requests[i].requestTime;
            processed[i] = requests[i].processed;
        }

        return (soloAmounts, stSOLOAmounts, requestTimes, processed);
    }

    /**
     * @notice Emergency SOLO Withdrawal Function
     * @notice Allows owner to withdraw SOLO tokens in case of emergency
     * @dev Implements strict access control and safety checks
     */
    function emergencyWithdrawToken(
        address token,
        address recipient, 
        uint256 amount
    ) external nonReentrant onlyOwner {
        // Deep security consideration - what if the soloToken address is malicious?
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        // Let me think about the IERC20 interface...
        // We need to safely interact with the SOLO token
        IERC20 erc20token = IERC20(token);
        
        // Critical check - do we have enough balance?
        uint256 contractBalance = erc20token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient token balance");

        // Before executing transfer, should we emit an event for transparency?
        emit EmergencyWithdrawal(
            token,
            recipient,
            amount
        );

        // Execute the transfer with best practices
        // Should we use transfer() or safeTransfer()?
        // SafeERC20 is generally preferred for maximum safety
        bool success = erc20token.transfer(recipient, amount);
        require(success, "Token transfer failed");
    }

     /// @dev Required by the OZ UUPS module
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
