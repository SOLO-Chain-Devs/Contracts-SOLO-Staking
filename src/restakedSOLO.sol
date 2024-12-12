// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RestakedSOLO is ERC20 {
    StakedSOLO public immutable ssolo;
    event Deposit(address indexed dst, uint256 amount);
    event Withdrawal(address indexed src, uint256 amount);

    constructor(address _ssolo) ERC20("Restaked SOLO", "rsSOLO") {
        ssolo = StakedSOLO(_ssolo);
    }

    // Deposit sSOLO to get rsSOLO
    function deposit(uint256 amount) external {
        require(ssolo.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    // Deposit sSOLO to get rsSOLO and send to another address
    function depositTo(address to, uint256 amount) external {
        require(ssolo.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _mint(to, amount);
        emit Deposit(to, amount);
    }

    // Withdraw sSOLO, burning rsSOLO
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        require(ssolo.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    // Allow withdrawal to another address
    function withdrawTo(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        require(ssolo.transfer(to, amount), "Transfer failed");
        emit Withdrawal(to, amount);
    }
}
