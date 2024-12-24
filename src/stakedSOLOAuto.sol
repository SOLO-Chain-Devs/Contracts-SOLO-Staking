// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./mock/SOLO.sol"; 

contract stakedSOLOAuto is ERC20, Ownable, ReentrancyGuard {
    SOLO public immutable soloToken;
    uint256 public lastRebaseTime;
    uint256 public constant REWARD_RATE = 100;
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public rewardPerSecond;
    
    mapping(address => uint256) private _shares;
    uint256 private _totalShares;
    uint256 private _shareRate = 1e18; // Initial rate 1:1
 
    mapping(address => bool) public whitelistedAddresses;
    
    constructor(address _soloToken) ERC20("Staked SOLO", "stSOLO") {
        soloToken = SOLO(_soloToken);
        lastRebaseTime = block.timestamp;
        rewardPerSecond = REWARD_RATE / SECONDS_PER_YEAR;
    }
     
    function setWhitelisted(address addr, bool status) external onlyOwner {
        whitelistedAddresses[addr] = status;
    }

    function calculateRebase() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastRebaseTime;
        return timeElapsed * rewardPerSecond;
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        
        // Skip rebase for whitelisted addresses
        if (whitelistedAddresses[from] || whitelistedAddresses[to]) {
            super._transfer(from, to, amount);
            return;
        }
        
        // Apply rebase before transfer
        uint256 reward = calculateRebase();
        if (reward > 0 && totalSupply() > 0) {
            uint256 ratio = (reward * 1e18) / totalSupply();
            _mint(address(this), reward);
            lastRebaseTime = block.timestamp;
        }
        
        super._transfer(from, to, amount);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        soloToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 shares = (amount * 1e18) / _shareRate;
        _shares[msg.sender] += shares;
        _totalShares += shares;
        _mint(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        uint256 shares = (amount * 1e18) / _shareRate;
        require(_shares[msg.sender] >= shares, "Insufficient shares");
        
        _shares[msg.sender] -= shares;
        _totalShares -= shares;
        _burn(msg.sender, amount);
        soloToken.transfer(msg.sender, amount);
    }

    function shareOf(address account) public view returns (uint256) {
        return (_shares[account] * _shareRate) / 1e18;
    }
    
}
