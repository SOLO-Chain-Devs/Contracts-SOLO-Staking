// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IGasMining {
    // Structs
    struct UnclaimedDetails {
        uint256 pendingAmount;
        uint256 lastClaimedBlock;
        uint256 missedBlocks;
        uint256[] unclaimedBlocks;
    }

    // Events
    event InstantRewardClaimed(address indexed user, uint256 burnAmount, uint256 userReward);
    event RewardStaked(address indexed user, address indexed stakingContract, uint256 amount);
    event UserClaimUpdated(address indexed user, uint256[] blocks, uint256[] amounts, uint256 totalAmount);
    event BlockRewardUpdated(uint256 newReward);
    event EpochDurationUpdated(uint256 newDuration);
    event LatestClaimableBlockUpdated(uint256 newBlock);
    event AdminWithdraw(address indexed admin, uint256 amount);
    event BurnBasisPointsUpdated(uint256 newBurnBasisPoints);

    // View Functions
    function token() external view returns (address);
    function blockReward() external view returns (uint256);
    function latestClaimableBlock() external view returns (uint256);
    function epochDuration() external view returns (uint256);
    function burnBasisPoints() external view returns (uint256);
    function getRunway() external view returns (uint256);
    function getPendingClaimAmount(address _user) external view returns (uint256);
    function getTotalClaimAmount(address _user) external view returns (uint256);
    function getLastClaimedBlock(address _user) external view returns (uint256);
    function getCurrentEpoch() external view returns (uint256);
    function getBlockClaimAmount(address _user, uint256 _block) external view returns (uint256);
    function getClaimedBlocks(address _user) external view returns (uint256[] memory);
    function getUnclaimedDetails(address _user) external view returns (UnclaimedDetails memory);

    // State-Changing Functions
    function instantClaimRewards() external;
    function stakeClaim(address _stakingContract) external;
    
    // Admin Functions
    function setBlockReward(uint256 _blockReward) external;
    function setEpochDuration(uint256 _epochDuration) external;
    function updateLatestClaimableBlock(uint256 _block) external;
    function adminWithdraw(uint256 amount) external;
    function updateUserClaim(address _user, uint256[] memory _blocks, uint256[] memory _amounts) external;
    function setBurnBasisPoints(uint256 _burnBasisPoints) external;
}
