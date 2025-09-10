// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interfaces for SOLO Staking and StSOLO Token Contracts
 * @notice Defines the core interface for interaction with SOLO staking and token systems
 * @dev Extracted from original contract implementations
 */

/**
 * @title ISOLOStaking
 * @notice Interface for the SOLO Staking contract functionality
 */
interface ISOLOStaking {
    // Events
    event Staked(address indexed staker, address indexed recipient, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 stSOLOAmount, uint256 soloAmount, uint256 requestId);
    event WithdrawalProcessed(address indexed user, uint256 soloAmount, uint256 requestId);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);

    // External functions
    function stake(uint256 _amount, address _recipient) external;
    function requestWithdrawal(uint256 stSOLOAmount) external;
    function processWithdrawal(uint256 _requestId) external;
    function setWithdrawalDelay(uint256 _newDelay) external;

    // View functions
    function getPendingWithdrawals(address _user)
        external
        view
        returns (
            uint256[] memory soloAmounts,
            uint256[] memory stSOLOAmounts,
            uint256[] memory requestTimes,
            bool[] memory processed
        );
    function soloToken() external view returns (address);
    function stSOLOToken() external view returns (address);
    function withdrawalDelay() external view returns (uint256);
}
