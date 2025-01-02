// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./StSOLOToken.sol";

contract SOLOStaking is Ownable, ReentrancyGuard {
    // State variables
    IERC20 public soloToken;
    StSOLOToken public stSOLOToken;
    
    uint256 public withdrawalDelay;
    uint256 public constant MIN_WITHDRAWAL_DELAY = 1 days;
    uint256 public constant MAX_WITHDRAWAL_DELAY = 30 days;

    struct WithdrawalRequest {
        uint256 soloAmount;    // Amount in SOLO tokens
        uint256 stSOLOAmount;  // Amount in stSOLO tokens at time of request
        uint256 requestTime;
        bool processed;
    }

    mapping(address => WithdrawalRequest[]) public withdrawalRequests;

    // Events
    event Staked(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);

    constructor(
        address _soloToken,
        address _stSOLOToken,
        uint256 _initialWithdrawalDelay
    ) Ownable(msg.sender) {
        require(
            _initialWithdrawalDelay >= MIN_WITHDRAWAL_DELAY &&
            _initialWithdrawalDelay <= MAX_WITHDRAWAL_DELAY,
            "Invalid delay"
        );
        
        soloToken = IERC20(_soloToken);
        stSOLOToken = StSOLOToken(_stSOLOToken);
        withdrawalDelay = _initialWithdrawalDelay;
    }

    // Admin functions
    function setWithdrawalDelay(uint256 _newDelay) external onlyOwner {
        require(_newDelay >= MIN_WITHDRAWAL_DELAY && 
                _newDelay <= MAX_WITHDRAWAL_DELAY, 
                "Invalid delay");
        emit WithdrawalDelayUpdated(withdrawalDelay, _newDelay);
        withdrawalDelay = _newDelay;
    }

    // Core staking functionality
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        
        require(soloToken.transferFrom(msg.sender, address(this), _amount),
                "SOLO transfer failed");

        // Mint stSOLO tokens to the user
        stSOLOToken.mint(msg.sender, _amount);
        
        emit Staked(msg.sender, _amount);
    }

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
        require(stSOLOToken.transferFrom(msg.sender, address(this), stSOLOAmount),
                "stSOLO transfer failed");
        stSOLOToken.burn(address(this), stSOLOAmount);

        emit WithdrawalRequested(msg.sender, stSOLOAmount, soloAmount, requestId);
    }

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

    // View functions
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
}
