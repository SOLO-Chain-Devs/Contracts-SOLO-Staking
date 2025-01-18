// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/upgradeable/SOLOStaking.sol";
import "../src/upgradeable/StSOLOToken.sol";
import "../src/upgradeable/lib/SOLOToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./lib/ScriptLogger.sol";

contract DeployScriptSOLOStaking is Script {
    using ScriptLogger for *;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementations
        SOLOToken soloTokenImplementation = new SOLOToken();
        StSOLOToken stSOLOImplementation = new StSOLOToken();
        SOLOStaking stakingImplementation = new SOLOStaking();

        // Deploy SOLOToken proxy
        bytes memory soloInitData = abi.encodeWithSelector(
            SOLOToken.initialize.selector
        );
        ERC1967Proxy soloProxy = new ERC1967Proxy(
            address(soloTokenImplementation),
            soloInitData
        );
        SOLOToken soloToken = SOLOToken(address(soloProxy));

        // Deploy StSOLOToken proxy
        uint256 initialTokensPerYearRate = 100_000 ether; // Customize as needed
        bytes memory stSOLOInitData = abi.encodeWithSelector(
            StSOLOToken.initialize.selector,
            initialTokensPerYearRate
        );
        ERC1967Proxy stSOLOProxy = new ERC1967Proxy(
            address(stSOLOImplementation),
            stSOLOInitData
        );
        StSOLOToken stSOLOToken = StSOLOToken(address(stSOLOProxy));

        // Deploy SOLOStaking proxy
        uint256 initialWithdrawalDelay = 7 days; // Customize as needed
        bytes memory stakingInitData = abi.encodeWithSelector(
            SOLOStaking.initialize.selector,
            address(soloToken),
            address(stSOLOToken),
            initialWithdrawalDelay
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(
            address(stakingImplementation),
            stakingInitData
        );
        SOLOStaking stakingContract = SOLOStaking(address(stakingProxy));

        // Link StSOLOToken to SOLOStaking
        stSOLOToken.setStakingContract(address(stakingContract));

        // Fund the deployer's account for testing
        soloToken.mintTo(msg.sender, 1_000_000 ether);

        vm.stopBroadcast();

        // Log deployment details
        ScriptLogger.logDeployment(
            "SOLO_TOKEN",
            address(soloTokenImplementation),
            address(soloProxy),
            address(0),
            0,
            0,
            block.number
        );

        ScriptLogger.logDeployment(
            "ST_SOLO_TOKEN",
            address(stSOLOImplementation),
            address(stSOLOProxy),
            address(0),
            initialTokensPerYearRate,
            0,
            block.number
        );

        ScriptLogger.logDeployment(
            "SOLO_STAKING",
            address(stakingImplementation),
            address(stakingProxy),
            address(soloToken),
            initialWithdrawalDelay,
            0,
            block.number
        );
    }
}