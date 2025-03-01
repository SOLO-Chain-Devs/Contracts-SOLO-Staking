// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SOLOToken is ERC20, Ownable {
    constructor() ERC20("SOLO TOKEN", "tSOLO") Ownable(msg.sender) {
    }
    
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function mintTo(address recepient, uint256 amount) public {
        _mint(recepient, amount);
    }
}

