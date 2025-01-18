// DummyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SOLOToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("SOLO Token", "SOLO");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function mintTo(address recepient, uint256 amount) public {
        _mint(recepient, amount);
    }

    /// @dev Required by the OZ UUPS module
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @dev Gap for future storage variables in upgrades
    uint256[50] private __gap;
}
