// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/mock/SOLO.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SOLO with initial supply
        uint256 initialSupply = 1_000_000_000e18; // 1 billion SOLO
        SOLO solo = new SOLO(initialSupply);
        console.log("SOLO deployed to:", address(solo));


        vm.stopBroadcast();

        // Log all deployment addresses for verification
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("SOLO:", address(solo));
    }
}
