// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "Caller is not the staking contract");
        _;
    }

    // Events
    event RebaseOccurred(uint256 totalSupply, uint256 rebaseAmount, uint256 excludedAmount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AddressExcluded(address indexed account, bool excluded);

    constructor(uint256 _initialRewardRate) ERC20("Staked SOLO", "stSOLO") Ownable(msg.sender) {
            rewardRate = _initialRewardRate;
            lastRebaseTime = block.timestamp;
        }

    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract address");
        stakingContract = _stakingContract;
    }

    // Exclusion management
    function setExcluded(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Invalid address");
        
        if (excluded && !excludedFromRebase[account]) {
            excludedFromRebase[account] = true;
            excludedAddresses.push(account);
        } else if (!excluded && excludedFromRebase[account]) {
            excludedFromRebase[account] = false;
            _removeFromExcludedAddresses(account);
        }
        
        emit AddressExcluded(account, excluded);
    }

    function _removeFromExcludedAddresses(address account) internal {
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            if (excludedAddresses[i] == account) {
                excludedAddresses[i] = excludedAddresses[excludedAddresses.length - 1];
                excludedAddresses.pop();
                break;
            }
        }
    }

    function getExcludedAddresses() external view returns (address[] memory) {
        return excludedAddresses;
    }

    function calculateExcludedAmount() public view returns (uint256) {
        uint256 totalExcluded = 0;
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            totalExcluded += balanceOf(excludedAddresses[i]);
        }
        return totalExcluded;
    }

    // Share-based accounting
    function shareOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    function _shareToAmount(uint256 share) internal view returns (uint256) {
        if (_totalShares == 0) return share;
        return (share * totalSupply()) / _totalShares;
    }

    function _amountToShare(uint256 amount) internal view returns (uint256) {
        if (_totalShares == 0) return amount;
        return (amount * _totalShares) / totalSupply();
    }

    // Core rebase functionality
    function rebase() external returns (uint256) {
        require(block.timestamp >= lastRebaseTime + 1 days, "Too soon to rebase");
        
        uint256 currentSupply = totalSupply();
        uint256 excludedAmount = calculateExcludedAmount();
        uint256 rebasableSupply = currentSupply - excludedAmount;
        
        if (rebasableSupply == 0) {
            lastRebaseTime = block.timestamp;
            return 0;
        }

        // Calculate rewards since last rebase
        uint256 timeElapsed = block.timestamp - lastRebaseTime;
        uint256 rewardPerSecond = rewardRate * 1e14 / SECONDS_PER_YEAR;
        uint256 rebaseAmount = (rebasableSupply * timeElapsed * rewardPerSecond) / 1e18;

        if (rebaseAmount > 0) {
            _mint(address(this), rebaseAmount);
            lastRebaseTime = block.timestamp;
        }

        emit RebaseOccurred(totalSupply(), rebaseAmount, excludedAmount);
        return rebaseAmount;
    }

    // Transfer and balance management
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        uint256 shareAmount = _amountToShare(amount);
        
        // Handle outgoing transfers and burns
        if (from != address(0)) {
            require(shareAmount <= _shares[from], "Insufficient shares");
            _shares[from] -= shareAmount;
        } else {
            // Minting new tokens, increase total shares
            _totalShares += shareAmount;
        }
        
        // Handle incoming transfers and mints
        if (to != address(0)) {
            _shares[to] += shareAmount;
        } else {
            // Burning tokens, decrease total shares
            _totalShares -= shareAmount;
        }
        
        super._update(from, to, amount);
    }

    function mint(address account, uint256 amount) external onlyStakingContract {
        uint256 shareAmount = _amountToShare(amount);
        _shares[account] += shareAmount;
        _totalShares += shareAmount;
        _mint(account, amount);
    }

    // Replace your existing burn function with this
    function burn(address account, uint256 amount) external onlyStakingContract {
        uint256 shareAmount = _amountToShare(amount);
        _shares[account] -= shareAmount;
        _totalShares -= shareAmount;
        _burn(account, amount);
    }    

    function balanceOf(address account) public view override returns (uint256) {
        return _shareToAmount(_shares[account]);
    }

    // Admin functions
    function setRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 3000, "Rate too high"); // Max 30% APR
        emit RewardRateUpdated(rewardRate, _newRate);
        rewardRate = _newRate;
    }
}
