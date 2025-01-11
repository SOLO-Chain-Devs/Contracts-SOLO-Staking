/**
 * @title StSOLO Token Contract
 * @author Original contract enhanced with NatSpec
 * @notice This contract implements a staking token that supports rebasing and exclusions
 * @dev Implements ERC20 with additional share-based accounting for rebasing functionality
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StSOLOToken
 * @notice A staked token contract that implements rebasing functionality with exclusion support
 * @dev Inherits from ERC20, Ownable, and ReentrancyGuard for core functionality
 *      Uses share-based accounting to handle rebasing correctly
 */
contract StSOLOToken is ERC20, Ownable, ReentrancyGuard {
    // Share accounting
    mapping(address => uint256) private _shares;
    uint256 private _totalShares;
    
    // Rebase exclusion system
    mapping(address => bool) public excludedFromRebase;
    address[] public excludedAddresses;
    
    // Core state variables
    uint256 public lastRebaseTime;
    uint256 public rewardRate; // Annual reward rate in basis points (1 = 0.01%)
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    address public stakingContract;
    
    uint256 public rebaseInterval;  // Time between rebases in seconds
    uint256 public constant MIN_REBASE_INTERVAL = 1 hours;
    uint256 public constant MAX_REBASE_INTERVAL = 30 days;
    address public constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint256 private _totalNormalShares;
    uint256 private _totalExcludedShares;
    uint256 private _tokenPerShare; // Tracks accumulated rewards per share
    uint256 private constant PRECISION_FACTOR = 1e18; // For decimal handling

    /**
     * @notice Ensures only the staking contract can call the function
     * @dev Modifier to restrict certain functions to the staking contract
     */
    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "Caller is not the staking contract");
        _;
    }

    // Events
    event RebaseOccurred(uint256 totalSupply, uint256 rebaseAmount, uint256 excludedAmount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AddressExcluded(address indexed account, bool excluded);
    // TODO added these to help
    event Minted(address indexed account, uint256 amount, uint256 shares);
    event Burned(address indexed account, uint256 amount, uint256 shares);
    event RebaseIntervalUpdated(uint256 interval);
    /**
     * @notice Contract constructor
     * @dev Initializes the contract with an initial reward rate
     * @param _initialRewardRate Initial annual reward rate in basis points
     */
    constructor(uint256 _initialRewardRate) ERC20("Staked SOLO", "stSOLO") Ownable(msg.sender) {
        rewardRate = _initialRewardRate;
        lastRebaseTime = block.timestamp;
        rebaseInterval = 1 days;

        // Initialize tokenPerShare at PRECISION_FACTOR for 1:1 initial ratio
        _tokenPerShare = PRECISION_FACTOR;

        // Initial mint with 1:1 ratio
        //uint256 INITIAL_AMOUNT = 1e18;
        uint256 INITIAL_AMOUNT = 1157920892373161954235709850086879078532699846655; 
        _mint(msg.sender, INITIAL_AMOUNT);
        _shares[msg.sender] = INITIAL_AMOUNT;
        _totalShares = INITIAL_AMOUNT;
        _totalNormalShares = INITIAL_AMOUNT; // Don't forget to initialize this
    }


    function setRebaseInterval(uint256 _newInterval) external onlyOwner {
        require(_newInterval >= MIN_REBASE_INTERVAL, "Interval too short");
        require(_newInterval <= MAX_REBASE_INTERVAL, "Interval too long");
        rebaseInterval = _newInterval;
        emit RebaseIntervalUpdated(rebaseInterval);
    }

    /**
     * @notice Sets the staking contract address
     * @dev Can only be called by the owner
     * @param _stakingContract Address of the staking contract
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract address");
        stakingContract = _stakingContract;
    }

    /**
     * @notice Manages exclusion status for an address
     * @dev Updates exclusion mappings and arrays
     * @param account Address to update exclusion status for
     * @param excluded New exclusion status
     */
    function setExcluded(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Invalid address");

        if (excluded && !excludedFromRebase[account]) {
            require(balanceOf(account) == 0, "Cannot exclude account with non-zero balance");
            excludedFromRebase[account] = true;
            excludedAddresses.push(account);
        } else if (!excluded && excludedFromRebase[account]) {
            excludedFromRebase[account] = false;
            _removeFromExcludedAddresses(account);
        }
        
        emit AddressExcluded(account, excluded);
    }

    /**
     * @notice Removes an address from the excluded addresses array
     * @dev Internal function to maintain excluded addresses list
     * @param account Address to remove from excluded list
     */
    function _removeFromExcludedAddresses(address account) internal {
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            if (excludedAddresses[i] == account) {
                excludedAddresses[i] = excludedAddresses[excludedAddresses.length - 1];
                excludedAddresses.pop();
                break;
            }
        }
    }

    /**
     * @notice Returns list of all excluded addresses
     * @return Array of addresses excluded from rebasing
     */
    function getExcludedAddresses() external view returns (address[] memory) {
        return excludedAddresses;
    }

    /**
     * @notice Calculates total token amount excluded from rebasing
     * @return Total amount of tokens excluded from rebasing
     */
    function calculateExcludedAmount() public view returns (uint256) {
        uint256 totalExcluded = 0;
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            totalExcluded += balanceOf(excludedAddresses[i]);
        }
        return totalExcluded;
    }

    /**
     * @notice Returns the share balance of an account
     * @param account Address to check shares for
     * @return Number of shares owned by the account
     */
    function shareOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @notice Returns the total number of shares
     * @return Total number of shares in existence
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @notice Converts shares to token amount
     * @param share Number of shares to convert
     * @return Equivalent token amount
     */
     function _shareToAmount(uint256 share) internal view returns (uint256) {
        if (_totalShares == 0) return share;
        if (excludedFromRebase[msg.sender]) {
            return share;
        }
        return (share * _tokenPerShare) / PRECISION_FACTOR;
    }

    /**
     * @notice Converts token amount to shares
     * @param amount Token amount to convert
     * @return Equivalent number of shares
     */
     function _amountToShare(uint256 amount) internal view returns (uint256) {
        if (_totalShares == 0) return amount;
        if (excludedFromRebase[msg.sender]) {
            return amount;
        }
        return (amount * PRECISION_FACTOR) / _tokenPerShare;
    }

    /**
     * @notice Performs rebase operation
     * @dev Distributes rewards to non-excluded token holders
     * @return Amount of tokens minted in the rebase
     */
    function rebase() external nonReentrant returns (uint256) {
        require(msg.sender == stakingContract || msg.sender == owner(), "Unauthorized");
        require(block.timestamp >= lastRebaseTime + rebaseInterval, "Too soon to rebase");
        
        uint256 currentSupply = totalSupply();
        uint256 excludedAmount = calculateExcludedAmount();
        uint256 rebasableSupply = currentSupply - excludedAmount;
        
        if (rebasableSupply == 0) {
            lastRebaseTime = block.timestamp;
            return 0;
        }

        // Calculate rebase amount as before
        uint256 timeElapsed = block.timestamp - lastRebaseTime;
        uint256 rebaseAmount = (rebasableSupply * timeElapsed * rewardRate) / (SECONDS_PER_YEAR * 10000);

        if (rebaseAmount > 0) {
            // Instead of minting, update tokenPerShare
            _tokenPerShare += (rebaseAmount * PRECISION_FACTOR) / _totalNormalShares;
            lastRebaseTime = block.timestamp;
        }

        emit RebaseOccurred(totalSupply(), rebaseAmount, excludedAmount);
        return rebaseAmount;
    }

    /**
     * @notice Updates token balances and shares during transfers
     * @dev Override of ERC20 _update to handle share accounting
     * @param from Address tokens are transferred from
     * @param to Address tokens are transferred to
     * @param amount Amount of tokens transferred
     */
function _update(address from, address to, uint256 amount) internal virtual override {
    uint256 shareAmount;
    if (excludedFromRebase[to] || excludedFromRebase[from]) {
        shareAmount = amount;
    } else {
        shareAmount = _amountToShare(amount);
    }
    
    if (from != address(0)) {
        require(shareAmount <= _shares[from], "Insufficient shares");
        _shares[from] -= shareAmount;
        if (!excludedFromRebase[from]) {
            _totalNormalShares -= shareAmount;
        }
    }
    
    if (to != address(0)) {
        _shares[to] += shareAmount;
        if (!excludedFromRebase[to]) {
            _totalNormalShares += shareAmount;
        }
    }
    
    super._update(from, to, amount);
}

    /**
     * @notice Mints new tokens
     * @dev Can only be called by staking contract
     * @param account Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address account, uint256 amount) external onlyStakingContract {
        if (excludedFromRebase[account]) {
            _totalExcludedShares += amount;
        } else {
            _totalNormalShares += _amountToShare(amount);
        }
        _mint(account, amount);
    }
    

    /**
     * @notice Burns tokens
     * @dev Can only be called by staking contract
     * @param account Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address account, uint256 amount) external onlyStakingContract nonReentrant {
        uint256 shareAmount = _amountToShare(amount);
        require(shareAmount <= _shares[account], "Insufficient shares");
        
        _shares[account] -= shareAmount;
        _totalShares -= shareAmount;
        _burn(account, amount);
        
        emit Burned(account, amount, shareAmount);
    }    

    /**
     * @notice Returns token balance of an account
     * @dev Override of ERC20 balanceOf to use share-based accounting
     * @param account Address to check balance for
     * @return Token balance of the account
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (excludedFromRebase[account]) {
            return _shares[account]; // Excluded accounts still work the same
        }
        // For normal accounts, multiply their shares by tokenPerShare
        return (_shares[account] * _tokenPerShare) / PRECISION_FACTOR;
    }

    /**
     * @notice Updates the reward rate
     * @dev Can only be called by owner, capped at 30% APR
     * @param _newRate New annual reward rate in basis points
     */
    function setRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 3000, "Rate too high"); // Max 30% APR
        emit RewardRateUpdated(rewardRate, _newRate);
        rewardRate = _newRate;
    }
}
