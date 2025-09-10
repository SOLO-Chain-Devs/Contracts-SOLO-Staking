// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IStSOLOToken
 * @notice Interface for the Staked SOLO Token contract functionality
 */
interface IStSOLOToken {
    // Events
    event RebaseOccurred(uint256 totalSupply, uint256 rebaseAmount, uint256 excludedAmount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AddressExcluded(address indexed account, bool excluded);
    event Minted(address indexed account, uint256 amount, uint256 shares);
    event Burned(address indexed account, uint256 amount, uint256 shares);
    event RebaseIntervalUpdated(uint256 interval);

    // External functions
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function rebase() external returns (uint256);
    function setRewardRate(uint256 _newRate) external;
    function setStakingContract(address _stakingContract) external;
    function setExcluded(address account, bool excluded) external;
    function setRebaseInterval(uint256 _newInterval) external;

    // View functions
    function shareOf(address account) external view returns (uint256);
    function totalShares() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function excludedFromRebase(address account) external view returns (bool);
    function getExcludedAddresses() external view returns (address[] memory);
    function calculateExcludedAmount() external view returns (uint256);

    // State variables (view functions)
    function lastRebaseTime() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function stakingContract() external view returns (address);
    function rebaseInterval() external view returns (uint256);
}
