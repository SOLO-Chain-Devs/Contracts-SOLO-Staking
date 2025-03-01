// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/core/mock/SOLOToken.sol"; // Assuming the SOLO token contract is in this path
import "../src/core/SOLOStaking.sol"; // Assuming staking contract is in this path
import "../src/core/StSOLOToken.sol"; // For checking balance after staking

/**
 * @title StakingDistributionScript
 * @notice Script to mint SOLO tokens and stake them to reach specific tier levels
 * @dev Uses the first 8 Anvil wallets to create the tier distribution
 */
contract StakingDistributionScript is Script {
    // Hardcoded contract addresses from the prompt
    address constant SOLO_TOKEN_ADDRESS = 0x913EaaB8Ed06E76fb5437b3F63843EA4288aB926; 
    address constant STOLO_TOKEN_ADDRESS = 0xF3Ef34F6574831E5A7D5F9cb88f996FB9B1fd084;
    address constant STAKING_CONTRACT_ADDRESS = 0x387A54EE3f7d010C17a4d03e07b6a27Dd2DF8a51;
    // Using stSOLO address from the staking contract's state variable
    // We'll retrieve this dynamically from the staking contract
    
    // Anvil wallets 
    address[8] wallets = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Wallet 0 - Bronze
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8, // Wallet 1 - Bronze
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, // Wallet 2 - Silver
        0x90F79bf6EB2c4f870365E785982E1f101E93b906, // Wallet 3 - Silver
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, // Wallet 4 - Gold
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, // Wallet 5 - Gold
        0x976EA74026E726554dB657fA54763abd0C3a0aa9, // Wallet 6 - Platinum
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955  // Wallet 7 - Platinum
    ];
    
    // Private keys corresponding to the wallets
    bytes32[8] private privateKeys = [
        bytes32(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80),
        bytes32(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d),
        bytes32(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a),
        bytes32(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6),
        bytes32(0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a),
        bytes32(0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba),
        bytes32(0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e),
        bytes32(0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356)
    ];
    
    // Tier amounts (in tokens) - based on the table provided
    // Bronze: 0 stSOLO (just for completeness)
    // Silver: 10 stSOLO
    // Gold: 50 stSOLO
    // Platinum: 100 stSOLO
    uint256[4] tierAmounts = [
        0 ether,      // Bronze - no staking needed
        11 ether,     // Silver
        51 ether,     // Gold
        101 ether     // Platinum
    ];

    function run() external {
        // Parse command line arguments
        string memory walletArg = vm.envOr("WALLET", string("all"));
        uint256 walletIndex = type(uint256).max;
        
        if (keccak256(bytes(walletArg)) != keccak256(bytes("all"))) {
            try vm.parseUint(walletArg) returns (uint256 parsed) {
                walletIndex = parsed;
                require(walletIndex < wallets.length, "Wallet index out of range");
            } catch {
                revert("Invalid wallet argument. Use 'all' or a wallet index (0-7)");
            }
        }
        
        console.log("=== SOLO Staking Distribution Script ===");
        if (walletIndex != type(uint256).max) {
            console.log("Running for wallet index: %d (%s)", walletIndex, wallets[walletIndex]);
        } else {
            console.log("Running for all wallets");
        }
        // Connect to contracts
        SOLOToken soloToken = SOLOToken(SOLO_TOKEN_ADDRESS);
        SOLOStaking stakingContract = SOLOStaking(STAKING_CONTRACT_ADDRESS);
        
        // Get stSOLO token address from staking contract
        address stSOLOTokenAddress = address(stakingContract.stSOLOToken());
        console.log("Retrieved stSOLO token address: %s", stSOLOTokenAddress);
        StSOLOToken stSOLOToken = StSOLOToken(stSOLOTokenAddress);
        
        // Verify contracts are properly set up
        console.log("=== Contract Verification ===");
        console.log("SOLO Token address: %s", SOLO_TOKEN_ADDRESS);
        console.log("SOLO Token name: %s", soloToken.name());
        console.log("SOLO Token symbol: %s", soloToken.symbol());
        
        console.log("Staking Contract address: %s", STAKING_CONTRACT_ADDRESS);
        console.log("Staking Contract's SOLO token: %s", address(stakingContract.soloToken()));
        console.log("Staking Contract's stSOLO token: %s", stSOLOTokenAddress);
        
        console.log("stSOLO Token name: %s", stSOLOToken.name());
        console.log("stSOLO Token symbol: %s", stSOLOToken.symbol());
        console.log("================================");
        
        console.log("Starting staking distribution...");
        
        // Process wallets according to CLI argument
        for (uint256 i = 0; i < wallets.length; i++) {
            // Skip wallets not specified if a specific wallet index was provided
            if (walletIndex != type(uint256).max && i != walletIndex) {
                continue;
            }
            uint256 tier;
            
            // Determine which tier this wallet belongs to
            if (i < 2) {
                tier = 0; // Bronze
            } else if (i < 4) {
                tier = 1; // Silver
            } else if (i < 6) {
                tier = 2; // Gold
            } else {
                tier = 3; // Platinum
            }
            
            // Amount to stake based on tier
            uint256 amountToStake = tierAmounts[tier];
            
            // Skip Bronze tier (no staking needed)
            if (tier == 0) {
                console.log("Wallet %s: Bronze tier (no staking required)", wallets[i]);
                continue;
            }
            
            console.log("Processing wallet %s for tier %d with %d tokens", wallets[i], tier, amountToStake);
            
            // Start broadcasting with the current wallet's private key
            vm.startBroadcast(uint256(privateKeys[i]));
            
            // 1. Mint SOLO tokens to the wallet
            console.log("Minting %d SOLO tokens to wallet %s", amountToStake, wallets[i]);
            soloToken.mint(amountToStake);
            
            // 2. Log the SOLO balance to verify minting
            uint256 soloBalance = soloToken.balanceOf(wallets[i]);
            console.log("Wallet now has %d SOLO tokens", soloBalance);
            
            // 3. Approve staking contract to spend tokens
            console.log("Approving staking contract to spend tokens");
            soloToken.approve(STAKING_CONTRACT_ADDRESS, amountToStake);
            
            // 4. Verify approval
            uint256 allowance = soloToken.allowance(wallets[i], STAKING_CONTRACT_ADDRESS);
            console.log("Staking contract allowance: %d SOLO tokens", allowance);
            
            // 5. Stake tokens
            console.log("Staking %d tokens for wallet %s", amountToStake, wallets[i]);
            stakingContract.stake(amountToStake, wallets[i]);
            
            vm.stopBroadcast();
            
            // Verify stSOLO balance (outside of broadcast to avoid transaction)
            uint256 stSOLOBalance = stSOLOToken.balanceOf(wallets[i]);
            console.log("Wallet %s now has %d stSOLO tokens", wallets[i], stSOLOBalance);
            
            // Verify the tier has been reached
            string memory tierName;
            if (tier == 1) tierName = "Silver";
            else if (tier == 2) tierName = "Gold";
            else tierName = "Platinum";
            
            if (stSOLOBalance >= tierAmounts[tier] -1 ether) {
                console.log("SUCCESS: Wallet has reached %s tier", tierName);
            } else {
                console.log("WARNING: Wallet did not reach %s tier! Expected %d but got %d", 
                    tierName, tierAmounts[tier], stSOLOBalance);
            }
        }
        
        console.log("=== Distribution Summary ===");
        for (uint256 i = 0; i < wallets.length; i++) {
            uint256 balance = stSOLOToken.balanceOf(wallets[i]);
            console.log("Wallet %d (%s): %d stSOLO tokens", i, wallets[i], balance);
        }
        console.log("================================");
        console.log("Staking distribution complete!");
    }
}
