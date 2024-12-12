// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./mock/SOLO.sol"; 

contract StakedSOLO is ERC20 {
    SOLO public immutable soloToken;
    event Deposit(address indexed dst, uint256 amount);
    event Withdrawal(address indexed src, uint256 amount);

    constructor(address _soloToken) ERC20("Staked SOLO", "sSOLO") {
        soloToken = SOLO(_soloToken);
    }

    // Deposit SOLO to get sSOLO
    function deposit(uint256 amount) external {
        require(soloToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    // Deposit SOLO to get sSOLO and send to another address
    function depositTo(address to, uint256 amount) external {
        require(soloToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _mint(to, amount);
        emit Deposit(to, amount);
    }

    // Withdraw SOLO, burning sSOLO (anyone can burn their sSOLO)
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        require(soloToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    // Allow withdrawal to another address
    function withdrawTo(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        require(soloToken.transfer(to, amount), "Transfer failed");
        emit Withdrawal(to, amount);
    }
}


