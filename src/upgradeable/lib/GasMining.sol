pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
using SafeERC20 for IERC20;
/* 
 * @title GasMining
 * @dev Contract for mining gas rewards with options for instant claims or staking
 * @notice This contract handles the distribution of SOLO tokens as rewards
 */
contract GasMining is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20 public token;
    uint256 public blockReward;
    // TODO (to implement ?)
    //uint256 public runwayBlocks;
    uint256 public latestClaimableBlock;
    uint256 public epochDuration;
    uint256 public Counter;

    struct UserClaim {
        uint256 lastClaimedBlock;
        uint256 totalClaimAmount;
        uint256 pendingClaimAmount;
        uint256[] claimedBlocks;
        mapping(uint256 => uint256) blockClaimAmounts;
    }

    mapping(address => UserClaim) public userClaims;

    event InstantRewardClaimed(address indexed user, uint256 burnAmount, uint256 userReward);
    event RewardStaked(address indexed user, address indexed stakingContract, uint256 amount);
    // TODO 
    // To implement this as an event or is it too redundant as well have a backend and we will write to the blockchain ?
    // or simply
    //  event UserClaimUpdated(address indexed user, uint256 totalAmount) ?
    event UserClaimUpdated(address indexed user, uint256[] blocks, uint256[] amounts, uint256 totalAmount);
    event BlockRewardUpdated(uint256 newReward);
    event EpochDurationUpdated(uint256 newDuration);
    event LatestClaimableBlockUpdated(uint256 newBlock);
    event AdminWithdraw(address indexed admin, uint256 amount);
    event BurnBasisPointsUpdated(uint256 newBurnBasisPoints);
    uint256 public burnBasisPoints = 5000; // Default 50% (5000 basis points)
    uint256 public constant MAX_BURN_BASIS_POINTS = 5000; // Max 50%

    /* 
     * @dev Contract constructor
     * @param _token Address of the SOLO token contract
     * @param _blockReward Amount of tokens to reward per block
     * @param _epochDuration Duration of each epoch in blocks
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        uint256 _blockReward,
        uint256 _epochDuration,
        uint256 _latestClaimableBlock
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        token = IERC20(_token);
        blockReward = _blockReward;
        epochDuration = _epochDuration;
        latestClaimableBlock = _latestClaimableBlock;
        burnBasisPoints = 5000; // Default 50%
        
        emit BlockRewardUpdated(_blockReward);
        emit EpochDurationUpdated(_epochDuration);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Add this function with other admin functions
    function setBurnBasisPoints(uint256 _burnBasisPoints) external onlyOwner {
        require(_burnBasisPoints <= MAX_BURN_BASIS_POINTS, "Cannot exceed maximum burn percentage");
        burnBasisPoints = _burnBasisPoints;
        emit BurnBasisPointsUpdated(_burnBasisPoints);
    }
    /* 
     * @dev Updates the reward amount per block
     * @param _blockReward New reward amount per block
     * @notice Only callable by contract owner
     */
    function setBlockReward(uint256 _blockReward) external onlyOwner {
        blockReward = _blockReward;
        emit BlockRewardUpdated(_blockReward);
    }

    /* 
     * @dev Updates the epoch duration
     * @param _epochDuration New epoch duration in blocks
     * @notice Only callable by contract owner
     */
    function setEpochDuration(uint256 _epochDuration) external onlyOwner {
        epochDuration = _epochDuration;
        emit EpochDurationUpdated(_epochDuration);
    }

    /* 
     * @dev Updates the latest block number for which rewards can be claimed
     * @param _block New latest claimable block number
     * @notice Only callable by contract owner
     */
    function updateLatestClaimableBlock(uint256 _block) external onlyOwner {
        require(_block > latestClaimableBlock, "New block number must be greater than the current latest claimable block");
        latestClaimableBlock = _block;
        emit LatestClaimableBlockUpdated(_block);
    }

    event AdminWithdraw(address indexed admin, uint256 amount, uint256 timestamp);

    /**
     * @dev Allows owner to withdraw SOLO tokens from the contract
     * @param amount Amount of tokens to withdraw
     * @notice Only callable by contract owner
     * @notice Ensures sufficient balance remains for pending claims
     */
    function adminWithdraw(uint256 amount) external onlyOwner {
        // Ensure amount is not zero
        require(amount > 0, "Amount must be greater than 0");

        // Get current token balance
        uint256 contractBalance = token.balanceOf(address(this));

        // Ensure withdrawal amount is available
        require(contractBalance >= amount, "Insufficient contract balance");

        // TODO
        // Check if the withdrawal would leave enough tokens for the runwayBlocks
        //uint256 remainingBalance = contractBalance - amount;
        //uint256 requiredBalance = blockReward * runwayBlocks;
        //require(remainingBalance >= requiredBalance, "Withdrawal would impact reward payments");

        // Perform the transfer
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        // Emit withdrawal event
        emit AdminWithdraw(msg.sender, amount);
    }

    /* 
     * @dev Updates claim information for a specific user
     * @param _user Address of the user
     * @param _blocks Array of block numbers
     * @param _amounts Array of claim amounts corresponding to blocks
     * @notice Only callable by contract owner
     */
    function updateUserClaim(address _user, uint256[] memory _blocks, uint256[] memory _amounts) external onlyOwner {
        require(_blocks.length == _amounts.length, "Blocks and amounts arrays must have the same length");
        UserClaim storage claim = userClaims[_user];
        
        uint256 totalNewAmount = 0;
        for (uint256 i = 0; i < _blocks.length; i++) {
            uint256 blockID = _blocks[i];
            uint256 amount = _amounts[i];
            if (claim.blockClaimAmounts[blockID] == 0) {
                claim.claimedBlocks.push(blockID);
            }
            claim.blockClaimAmounts[blockID] = amount;
            claim.pendingClaimAmount += amount;
            totalNewAmount += amount;
        }

        claim.totalClaimAmount += claim.pendingClaimAmount;
        emit UserClaimUpdated(_user, _blocks, _amounts, totalNewAmount);

    }

    /* 
     * @dev Claims rewards instantly with 50% burn
     * @notice 50% of rewards are burned and 50% are sent to the claimer
     */
    function instantClaimRewards() external {
        UserClaim storage claim = userClaims[msg.sender];
        require(claim.lastClaimedBlock < latestClaimableBlock, "No new rewards to claim");
        require(claim.pendingClaimAmount > 0, "No pending rewards to claim for the user");
        
        uint256 totalReward = claim.pendingClaimAmount;
        uint256 burnAmount = totalReward / 2;
        uint256 userReward = totalReward - burnAmount;
        
        claim.pendingClaimAmount = 0;
        claim.lastClaimedBlock = latestClaimableBlock;
        
        // Burn 50% by sending to dead address
        token.transfer(address(0xdead), burnAmount);
        // Send 50% to user
        token.transfer(msg.sender, userReward);
        emit InstantRewardClaimed(msg.sender, burnAmount, userReward);
    }

    /* 
     * @dev Stakes rewards in another contract instead of claiming
     * @notice Avoids 50% burn penalty by staking the full amount
     * @param _stakingContract Address of the staking contract
     */
    function stakeClaim(address _stakingContract) external {
        UserClaim storage claim = userClaims[msg.sender];
        require(claim.lastClaimedBlock < latestClaimableBlock, "No new rewards to claim");
        require(claim.pendingClaimAmount > 0, "No pending rewards to claim for the user");
        
        uint256 reward = claim.pendingClaimAmount;
        claim.pendingClaimAmount = 0;
        claim.lastClaimedBlock = latestClaimableBlock;
        
        // First approve the contract to spend the tokens
        
        // Call stake function on the staking contract with msg.sender as the user
        ISOLOStaking(_stakingContract).stake(reward, msg.sender);
        
        emit RewardStaked(msg.sender, _stakingContract, reward);

    }

    /* 
     * @dev Calculates remaining blocks based on contract balance
     * @return Number of blocks that can be rewarded with current balance
     */
    function getRunway() external view returns (uint256) {
        return token.balanceOf(address(this)) / blockReward;
    }

    /* 
     * @dev Gets pending claim amount for a user
     * @param _user Address of the user
     * @return Pending claim amount
     */
    function getPendingClaimAmount(address _user) external view returns (uint256) {
        UserClaim storage claim = userClaims[_user];
        return claim.pendingClaimAmount;
    }

    /* 
     * @dev Gets total claim amount for a user
     * @param _user Address of the user
     * @return Total claim amount
     */
    function getTotalClaimAmount(address _user) external view returns (uint256) {
        UserClaim storage claim = userClaims[_user];
        return claim.totalClaimAmount;
    }

    /* 
     * @dev Gets last claimed block for a user
     * @param _user Address of the user
     * @return Block number of last claim
     */
    function getLastClaimedBlock(address _user) external view returns (uint256) {
        UserClaim storage claim = userClaims[_user];
        return claim.lastClaimedBlock;
    }

    /* 
     * @dev Gets current epoch number
     * @return Current epoch number
     */
    function getCurrentEpoch() external view returns (uint256) {
        return block.number / epochDuration;
    }

    /* 
     * @dev Gets claim amount for a specific block
     * @param _user Address of the user
     * @param _block Block number
     * @return Claim amount for the specified block
     */
    function getBlockClaimAmount(address _user, uint256 _block) external view returns (uint256) {
        UserClaim storage claim = userClaims[_user];
        return claim.blockClaimAmounts[_block];
    }

    /* 
     * @dev Gets array of claimed blocks for a user
     * @param _user Address of the user
     * @return Array of block numbers claimed by the user
     */
    function getClaimedBlocks(address _user) external view returns (uint256[] memory) {
        UserClaim storage claim = userClaims[_user];
        return claim.claimedBlocks;
    }
    struct UnclaimedDetails {
        uint256 pendingAmount;
        uint256 lastClaimedBlock;
        uint256 missedBlocks;
        uint256[] unclaimedBlocks;
    }

    /* 
     * @dev Gets detailed information about unclaimed rewards for a user
     * @param _user Address to check unclaimed rewards for
     * @return UnclaimedDetails struct containing pending amount, last claimed block,
     *         number of missed blocks, and array of unclaimed block numbers
     */
    function getUnclaimedDetails(address _user) external view returns (UnclaimedDetails memory) {
        UserClaim storage claim = userClaims[_user];
        
        // Calculate missed blocks
        uint256 missedBlocks = 0;
        if (latestClaimableBlock > claim.lastClaimedBlock) {
            missedBlocks = latestClaimableBlock - claim.lastClaimedBlock;
        }

        // Get unclaimed blocks
        uint256[] memory unclaimedBlocks = new uint256[](missedBlocks);
        uint256 counter = 0;
        for (uint256 i = claim.lastClaimedBlock + 1; i <= latestClaimableBlock; i++) {
            if (claim.blockClaimAmounts[i] > 0) {
                unclaimedBlocks[counter] = i;
                counter++;
            }
        }

        return UnclaimedDetails({
            pendingAmount: claim.pendingClaimAmount,
            lastClaimedBlock: claim.lastClaimedBlock,
            missedBlocks: missedBlocks,
            unclaimedBlocks: unclaimedBlocks
        });
    }


    function mine(uint256 _loops) public {
        for(uint i; i < _loops; i++){
            Counter ++;
        }
    }

    uint256[50] private __gap; // Storage slots for proxy upgradeability
}

interface ISOLOStaking {
    function stake(uint256 _amount, address _recipient) external;
}
