// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Upgradeable StSOLOToken
 * @notice A staked token contract that implements rebasing functionality with exclusion support
 * @dev Inherits from ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable, and ReentrancyGuardUpgradeable
 *      Uses share-based accounting to handle rebasing correctly
 */
contract StSOLOToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
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
    uint256 public constant MAX_TOKENS_PER_YEAR = 100_000_000_000 ether;
    uint256 private _totalNormalShares;
    uint256 private _totalExcludedShares;
    uint256 private _tokenPerShare; // Tracks accumulated rewards per share
    uint256 public constant PRECISION_FACTOR = 1e18; // For decimal handling
    uint256 public tokensPerYear;

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
    event Minted(address indexed account, uint256 amount, uint256 shares);
    event Burned(address indexed account, uint256 amount, uint256 shares);
    event RebaseIntervalUpdated(uint256 interval);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Contract initializer
     * @dev Initializes the contract with initial parameters
     * @param _tokensPerYear Initial annual reward in tokens per year
     */
    function initialize(uint256 _tokensPerYear) public initializer {
        __ERC20_init("Staked SOLO", "stSOLO");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        tokensPerYear = _tokensPerYear;
        lastRebaseTime = block.timestamp;
        rebaseInterval = 12 hours;

        // Initialize tokenPerShare at PRECISION_FACTOR for 1:1 initial ratio
        _tokenPerShare = PRECISION_FACTOR;
    }

    //TODO might need to remove these getter functions. Written for tests
    function getTokenPerShare() public view returns (uint256) {
        return _tokenPerShare;
    }

    function getTotalNormalShares() public view returns (uint256) {
        return _totalNormalShares;
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
     function _shareToAmount(uint256 share) public view returns (uint256) {
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
     function _amountToShare(uint256 amount) public view returns (uint256) {
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
    function rebase() public nonReentrant returns (uint256) {
        require(msg.sender == stakingContract || msg.sender == owner(), "Unauthorized");
        require(block.timestamp >= lastRebaseTime + rebaseInterval, "Too soon to rebase");
        
        uint256 excludedAmount = calculateExcludedAmount();
        uint256 rebasableSupply = totalSupply() - excludedAmount;
        
        if (rebasableSupply == 0) {
            lastRebaseTime = block.timestamp;
            return 0;
        }

        // Calculate tokens to emit based on fixed yearly rate
        uint256 timeElapsed = block.timestamp - lastRebaseTime;
        uint256 rebaseAmount = (tokensPerYear * timeElapsed) / SECONDS_PER_YEAR;
        
        if (rebaseAmount > 0) {
            // Update tokenPerShare based on fixed emission
            uint256 shareIncrement = (rebaseAmount * PRECISION_FACTOR * 2) / _totalNormalShares;
            _tokenPerShare += shareIncrement;
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
        if (to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        uint256 shareAmount;
        if (excludedFromRebase[to] || excludedFromRebase[from]) {
            shareAmount = amount;
        } else {
            shareAmount = _amountToShare(amount);
        }
        
        if (from != address(0)) {
            require(shareAmount <= _shares[from], "Insufficient shares during update");
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
        _totalShares += amount;
        _mint(account, amount);
    }
    

    /**
     * @notice Burns tokens
     * @dev Can only be called by staking contract
     * @param account Address to burn tokens from
     * @param tokenAmount Amount of tokenAmount to burn
     */
    function burn(address account, uint256 tokenAmount) external onlyStakingContract nonReentrant {
    uint256 accountShares = _shares[account];
    uint256 accountBalance = balanceOf(account);  // This already handles excluded vs non-excluded
    uint256 currentERC20Balance = super.balanceOf(account);  // Add this - get raw ERC20 balance
    
    // Calculate proportional shares to burn
    uint256 shareAmount = (tokenAmount * PRECISION_FACTOR) / _tokenPerShare;
    //uint256 shareAmount = (accountShares * tokenAmount) / accountBalance;
    
    require(shareAmount <= accountShares, "Insufficient shares");
    require(shareAmount > 0, "Zero shares");
    require(tokenAmount <= accountBalance, "Burn amount exceeds balance");
    
    if (tokenAmount > currentERC20Balance) {
        uint256 mintRequired = tokenAmount - currentERC20Balance;
        super._mint(account, mintRequired);  // Explicit super call. Needed because we mix ERC20 with this weird rebase architecture
    }

    _shares[account] -= shareAmount;
    _totalShares -= shareAmount;
    if (!excludedFromRebase[account]) {
        _totalNormalShares -= shareAmount;
    }
    
    _burn(account, tokenAmount);
    
    emit Burned(account, tokenAmount, shareAmount);
}


    /**
    * @notice Burns tokens
        * @dev Can only be called by staking contract
        * @param account Address to burn tokens from
        * @param amount Amount of tokens to burn
        function burn(address account, uint256 amount) external onlyStakingContract nonReentrant {
        emit Debug_BurnAttempt(account, amount, _shares[account]);
        uint256 shareAmount = _amountToShare(amount);
        require(shareAmount <= _shares[account], "Insufficient shares");

        _shares[account] -= shareAmount;
        _totalShares -= shareAmount;
        _burn(account, amount);

        emit Burned(account, amount, shareAmount);
    }
        */

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
     * @notice Updates the reward tokensPerYear rate
     * @dev Can only be called by owner, capped at a specific value
     * @param _newTokensPerYear New annual reward rate in basis points
     */
    function setRewardTokensPerYear(uint256 _newTokensPerYear) external onlyOwner {
        require(_newTokensPerYear <= MAX_TOKENS_PER_YEAR, "TokensPerYear inflation exceeds max"); 
        rebase();
        tokensPerYear = _newTokensPerYear;
        emit RewardRateUpdated(tokensPerYear, _newTokensPerYear);
    }

    /// @dev Required by the OZ UUPS module
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
