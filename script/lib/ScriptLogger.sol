// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/console.sol";
import "forge-std/console2.sol";

library ScriptLogger {
    string private constant SEPARATOR =
        "================================================================================";

    function logDeployment(
        string memory contractName,
        address implementation,
        address proxy,
        address tokenAddress,
        uint256 blockReward,
        uint256 epochDuration,
        uint256 startBlock
    ) internal pure {
        console.log("%s", SEPARATOR);
        console.log(unicode"📦 %s CONTRACT DEPLOYMENT", contractName);
        console.log("%s", SEPARATOR);

        console.log(unicode"\n🔧 Contract Details:");
        console.log(unicode"  • Contract Name: %s", contractName);
        console.log(unicode"  • Implementation: %s", implementation);
        console.log(unicode"  • Proxy: %s", proxy);

        if (tokenAddress != address(0)) {
            console.log(unicode"\n🚀 Initialization Parameters:");
            console.log(unicode"  • Token Address: %s", tokenAddress);
            if (blockReward > 0) {
                console.log(
                    unicode"  • Block Reward: %d wei (~%d.%d SOLO)",
                    blockReward,
                    blockReward / 1e18,
                    (blockReward % 1e18) / 1e15
                );
            }
            if (epochDuration > 0) {
                console.log(
                    unicode"  • Epoch Duration: %d blocks (~%d.%d hours)",
                    epochDuration,
                    (epochDuration * 12) / 3600,
                    ((epochDuration * 12) % 3600) * 10 / 3600
                );
            }
            console.log(unicode"  • Starting Block: %d", startBlock);
        }

        console.log(unicode"\n✅ Deployment completed successfully");
        console.log("%s\n", SEPARATOR);

        console.log(unicode"\n📋 For verification:");
        console.log("export IMPLEMENTATION=%s", implementation);
        console.log("export PROXY=%s\n", proxy);
    }

    function logUpgrade(string memory contractName, address newImplementation, address proxyAddress) internal pure {
        console.log("%s", SEPARATOR);
        console.log(unicode"🔄 %s CONTRACT UPGRADE", contractName);
        console.log("%s", SEPARATOR);

        console.log(unicode"\n🔧 Upgrade Details:");
        console.log(unicode"  • Contract Name: %s", contractName);
        console.log(unicode"  • New Implementation: %s", newImplementation);
        console.log(unicode"  • Proxy Address: %s", proxyAddress);

        console.log(unicode"\n✅ Upgrade completed successfully");
        console.log("%s\n", SEPARATOR);

        console.log(unicode"\n📋 For verification:");
        console.log("export NEW_IMPLEMENTATION=%s", newImplementation);
        console.log("export PROXY=%s\n", proxyAddress);
    }
}
