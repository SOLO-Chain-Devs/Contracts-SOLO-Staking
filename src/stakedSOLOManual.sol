// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./mock/SOLO.sol"; 

contract StakedSOLOManual is ERC20, Ownable, ReentrancyGuard {
    SOLO public immutable soloToken;
    uint256 public lastRebaseTime;
    uint256 public constant REWARD_RATE = 100; // 100 SOLO total rewards
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public rewardPerSecond;
    
    // Track internal balances at a higher precision
    mapping(address => uint256) private _shares;
    uint256 private _totalShares;
    uint256 private _shareRate = 1e18; // Initial rate 1:1
    
    constructor(address _soloToken, address initialOwner) ERC20("StakedSOLOR1", "stSOLOR1") Ownable(initialOwner){
        soloToken = SOLO(_soloToken);
        lastRebaseTime = block.timestamp;
        rewardPerSecond = REWARD_RATE / SECONDS_PER_YEAR;
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
    
    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
        if (from != address(0) && to != address(0)) {
            uint256 shares = (amount * 1e18) / _shareRate;
            _shares[from] -= shares;
            _shares[to] += shares;
        }
    }
    
    function rebase() external onlyOwner {
        uint256 timeElapsed = block.timestamp - lastRebaseTime;
        if (timeElapsed > 0 && _totalShares > 0) {
            uint256 totalReward = timeElapsed * rewardPerSecond;
            _shareRate = _shareRate * (totalSupply() + totalReward) / totalSupply();
            _mint(address(this), totalReward);
            lastRebaseTime = block.timestamp;
        }
    }
    
    function shareOf(address account) public view returns (uint256) {
        return (_shares[account] * _shareRate) / 1e18;
    }
}

