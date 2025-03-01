// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/core/StSOLOToken.sol"; // For checking stSOLO balances

/**
 * @title GasTransactionSimulator
 * @notice Script to simulate gas transactions within the same block across different wallets
 * @dev Simulates various tier-based reward calculation scenarios
 */
contract GasTransactionSimulator is Script {
    // Hardcoded contract addresses
    address constant STSOLO_TOKEN_ADDRESS = 0xF3Ef34F6574831E5A7D5F9cb88f996FB9B1fd084;
    
    // Define tier thresholds
    uint256 constant BRONZE_THRESHOLD = 0 ether;
    uint256 constant SILVER_THRESHOLD = 10 ether;
    uint256 constant GOLD_THRESHOLD = 50 ether;
    uint256 constant PLATINUM_THRESHOLD = 100 ether;
    
    // Define tier multipliers
    uint256 constant BRONZE_MULTIPLIER = 100;    // 1.0x
    uint256 constant SILVER_MULTIPLIER = 150;    // 1.5x
    uint256 constant GOLD_MULTIPLIER = 200;      // 2.0x
    uint256 constant PLATINUM_MULTIPLIER = 300;  // 3.0x
    
    // Anvil wallets with their private keys
    address[8] wallets = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Wallet 0
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8, // Wallet 1
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, // Wallet 2
        0x90F79bf6EB2c4f870365E785982E1f101E93b906, // Wallet 3
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, // Wallet 4
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, // Wallet 5
        0x976EA74026E726554dB657fA54763abd0C3a0aa9, // Wallet 6
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955  // Wallet 7
    ];
    
    uint256[8] private privateKeys = [
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80,
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d,
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a,
        0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6,
        0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a,
        0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba,
        0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e,
        0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
    ];
    
    // Struct to track user information for a scenario
    struct User {
        address wallet;
        uint256 privateKey;
        uint256 stSOLOBalance;
        string tier;
        uint256 multiplier;
        uint256 gasPercentage;
        uint256 iterations; // For gas consumption
    }
    
    // Struct to track scenario details
    struct ScenarioData {
        string name;
        User[] users;
    }

    // Track gas usage for each wallet in a scenario
    mapping(string => mapping(address => uint256)) public scenarioGasUsed;
    
    // Gas consumer contract
    address payable gasConsumerAddress;
    
    function run() external {
        // Deploy gas consumer contract first
        vm.startBroadcast(privateKeys[0]);
        GasConsumer gasConsumer = new GasConsumer();
        gasConsumerAddress = payable(address(gasConsumer));
        vm.stopBroadcast();
        
        console.log("Gas Consumer contract deployed at:", gasConsumerAddress);
        
        // Get current stSOLO balances
        StSOLOToken stSoloToken = StSOLOToken(STSOLO_TOKEN_ADDRESS);
        console.log("\n=== Current stSOLO Balances ===");
        for (uint256 i = 0; i < wallets.length; i++) {
            uint256 balance = stSoloToken.balanceOf(wallets[i]);
            string memory tier = getTierName(balance);
            console.log(
                string.concat(
                    "Wallet ", 
                    vm.toString(i), 
                    " (", 
                    vm.toString(wallets[i]), 
                    "): ",
                    vm.toString(balance / 1e18),
                    " stSOLO - ",
                    tier,
                    " tier"
                )
            );
        }
        
        // Run all scenarios
        runScenario1();
        runScenario2();
        runScenario3();
        runScenario4();
        runScenario5();
        runScenario6();
        runScenario7();
    }
    
    // Helper function to get tier name based on stSOLO balance
    function getTierName(uint256 balance) internal pure returns (string memory) {
        if (balance >= PLATINUM_THRESHOLD) {
            return "Platinum";
        } else if (balance >= GOLD_THRESHOLD) {
            return "Gold";
        } else if (balance >= SILVER_THRESHOLD) {
            return "Silver";
        } else {
            return "Bronze";
        }
    }
    
    // Helper function to get tier multiplier
    function getTierMultiplier(uint256 balance) internal pure returns (uint256) {
        if (balance >= PLATINUM_THRESHOLD) {
            return PLATINUM_MULTIPLIER;
        } else if (balance >= GOLD_THRESHOLD) {
            return GOLD_MULTIPLIER;
        } else if (balance >= SILVER_THRESHOLD) {
            return SILVER_MULTIPLIER;
        } else {
            return BRONZE_MULTIPLIER;
        }
    }
    
    // Helper function to calculate reward distribution
    function calculateRewards(ScenarioData memory scenario) internal pure {
        console.log("\nReward Calculations:");
        console.log("| User | Pre-Boost | Actual | Comparative |");
        console.log("|------|-----------|--------|-------------|");
        
        // Calculate total weighted gas
        uint256 totalWeightedGas = 0;
        for (uint256 i = 0; i < scenario.users.length; i++) {
            totalWeightedGas += scenario.users[i].gasPercentage * scenario.users[i].multiplier;
        }
        
        // Calculate rewards for each user
        for (uint256 i = 0; i < scenario.users.length; i++) {
            User memory user = scenario.users[i];
            
            // Pre-boost percentage is just the gas percentage
            uint256 preBoost = user.gasPercentage;
            
            // Actual reward is weighted by multiplier
            uint256 actual = (user.gasPercentage * user.multiplier * 100) / totalWeightedGas;
            
            // Comparative value (percentage of percentage)
            uint256 comparative = (preBoost * 100) / user.multiplier;
            
            // Print the row
            console.log(
                string.concat(
                    "| ", string(abi.encodePacked(bytes1(uint8(65 + i)))), // A, B, C...
                    "    | ",
                    vm.toString(preBoost),
                    "%" , (preBoost < 10 ? "        " : (preBoost < 100 ? "       " : "      ")),
                    "| ",
                    vm.toString(actual / 100), ".", vm.toString((actual % 100) / 10), vm.toString(actual % 10), "%",
                    actual < 1000 ? "   " : "  ",
                    "| ",
                    vm.toString(comparative / 100), ".", vm.toString((comparative % 100) / 10), vm.toString(comparative % 10), "%",
                    comparative < 1000 ? "       " : "      ",
                    "|"
                )
            );
        }
    }
    
    // SCENARIO 1: Single User (Any Tier)
    function runScenario1() internal {
        string memory scenarioName = "SCENARIO 1: Single User (Gold Tier)";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Only one user (Gold tier, 100% gas)
        User[] memory users = new User[](1);
        users[0] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 75 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 100,
            iterations: 5000 // High gas usage
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 2: Two Users, Different Tiers
    function runScenario2() internal {
        string memory scenarioName = "SCENARIO 2: Two Users, Different Tiers";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Two users - Gold and Bronze with 50% gas each
        User[] memory users = new User[](2);
        users[0] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 75 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 50,
            iterations: 250
        });
        
        users[1] = User({
            wallet: wallets[0], // Bronze tier wallet
            privateKey: privateKeys[0],
            stSOLOBalance: 5 ether,
            tier: "Bronze",
            multiplier: BRONZE_MULTIPLIER,
            gasPercentage: 50,
            iterations: 250
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 3: Complex Multi-Tier (Equal Gas)
    function runScenario3() internal {
        string memory scenarioName = "SCENARIO 3: Complex Multi-Tier (Equal Gas)";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Four users - All tiers with 25% gas each
        User[] memory users = new User[](4);
        users[0] = User({
            wallet: wallets[6], // Platinum tier wallet
            privateKey: privateKeys[6],
            stSOLOBalance: 150 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[1] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 60 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[2] = User({
            wallet: wallets[2], // Silver tier wallet
            privateKey: privateKeys[2],
            stSOLOBalance: 15 ether,
            tier: "Silver",
            multiplier: SILVER_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[3] = User({
            wallet: wallets[0], // Bronze tier wallet
            privateKey: privateKeys[0],
            stSOLOBalance: 5 ether,
            tier: "Bronze",
            multiplier: BRONZE_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 4: Multiple Platinum Users (Equal Gas)
    function runScenario4() internal {
        string memory scenarioName = "SCENARIO 4: Multiple Platinum Users (Equal Gas)";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Three Platinum users
        User[] memory users = new User[](3);
        users[0] = User({
            wallet: wallets[6], // Platinum tier wallet
            privateKey: privateKeys[6],
            stSOLOBalance: 150 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 33,
            iterations: 165
        });
        
        users[1] = User({
            wallet: wallets[7], // Platinum tier wallet
            privateKey: privateKeys[7],
            stSOLOBalance: 200 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 33,
            iterations: 165
        });
        
        users[2] = User({
            wallet: wallets[5], // Gold wallet treated as Platinum for this scenario
            privateKey: privateKeys[5],
            stSOLOBalance: 120 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 34,
            iterations: 170
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 5: Mixed Platinum & Gold Users
    function runScenario5() internal {
        string memory scenarioName = "SCENARIO 5: Mixed Platinum & Gold Users";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Two Platinum and two Gold users
        User[] memory users = new User[](4);
        users[0] = User({
            wallet: wallets[6], // Platinum tier wallet
            privateKey: privateKeys[6],
            stSOLOBalance: 150 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[1] = User({
            wallet: wallets[7], // Platinum tier wallet
            privateKey: privateKeys[7],
            stSOLOBalance: 180 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[2] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 60 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        users[3] = User({
            wallet: wallets[5], // Gold tier wallet
            privateKey: privateKeys[5],
            stSOLOBalance: 55 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 25,
            iterations: 125
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 6: Mixed Tiers & Uneven Gas
    function runScenario6() internal {
        string memory scenarioName = "SCENARIO 6: Mixed Tiers & Uneven Gas";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Platinum and Gold with uneven gas
        User[] memory users = new User[](2);
        users[0] = User({
            wallet: wallets[6], // Platinum tier wallet
            privateKey: privateKeys[6],
            stSOLOBalance: 120 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 40,
            iterations: 200
        });
        
        users[1] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 55 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 60,
            iterations: 300
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // SCENARIO 7: All Tiers Represented with Multiple Users
    function runScenario7() internal {
        string memory scenarioName = "SCENARIO 7: All Tiers Represented with Multiple Users";
        console.log("\n=== ", scenarioName, " ===");
        
        // Define users for this scenario
        ScenarioData memory scenario;
        scenario.name = scenarioName;
        
        // Seven users across all tiers
        User[] memory users = new User[](7);
        users[0] = User({
            wallet: wallets[6], // Platinum tier wallet
            privateKey: privateKeys[6],
            stSOLOBalance: 150 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 15,
            iterations: 75
        });
        
        users[1] = User({
            wallet: wallets[7], // Platinum tier wallet
            privateKey: privateKeys[7],
            stSOLOBalance: 180 ether,
            tier: "Platinum",
            multiplier: PLATINUM_MULTIPLIER,
            gasPercentage: 15,
            iterations: 75
        });
        
        users[2] = User({
            wallet: wallets[4], // Gold tier wallet
            privateKey: privateKeys[4],
            stSOLOBalance: 60 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 20,
            iterations: 100
        });
        
        users[3] = User({
            wallet: wallets[5], // Gold tier wallet
            privateKey: privateKeys[5],
            stSOLOBalance: 55 ether,
            tier: "Gold",
            multiplier: GOLD_MULTIPLIER,
            gasPercentage: 15,
            iterations: 75
        });
        
        users[4] = User({
            wallet: wallets[2], // Silver tier wallet
            privateKey: privateKeys[2],
            stSOLOBalance: 15 ether,
            tier: "Silver",
            multiplier: SILVER_MULTIPLIER,
            gasPercentage: 15,
            iterations: 75
        });
        
        users[5] = User({
            wallet: wallets[3], // Silver tier wallet
            privateKey: privateKeys[3],
            stSOLOBalance: 20 ether,
            tier: "Silver",
            multiplier: SILVER_MULTIPLIER,
            gasPercentage: 10,
            iterations: 50
        });
        
        users[6] = User({
            wallet: wallets[0], // Bronze tier wallet
            privateKey: privateKeys[0],
            stSOLOBalance: 5 ether,
            tier: "Bronze",
            multiplier: BRONZE_MULTIPLIER,
            gasPercentage: 10,
            iterations: 50
        });
        
        scenario.users = users;
        
        // Print user details
        printScenarioUsers(scenario);
        
        // Simulate gas usage in a single block
        simulateGasUsage(scenario);
        
        // Calculate rewards
        calculateRewards(scenario);
    }
    
    // Function to print user details for a scenario
    function printScenarioUsers(ScenarioData memory scenario) internal view {
        console.log("User Details & Gas Share:");
        console.log("| User | stSOLO | Tier     | Multiplier | Gas % |");
        console.log("|------|---------|----------|------------|-------|");
        
        for (uint256 i = 0; i < scenario.users.length; i++) {
            User memory user = scenario.users[i];
            
            console.log(
                string.concat(
                    "| ", string(abi.encodePacked(bytes1(uint8(65 + i)))), // A, B, C...
                    "    | ",
                    vm.toString(user.stSOLOBalance / 1e18),
                    "      | ",
                    user.tier,
                    getSpaces(10 - bytes(user.tier).length),
                    "| ",
                    vm.toString(user.multiplier / 100), ".", vm.toString(user.multiplier % 100 / 10), "x",
                    "       | ",
                    vm.toString(user.gasPercentage),
                    "%" , (user.gasPercentage < 10 ? "    " : (user.gasPercentage < 100 ? "   " : "  ")),
                    "|"
                )
            );
        }
    }
    
    // Helper function to get spaces for table formatting
    function getSpaces(uint256 count) internal pure returns (string memory) {
        string memory spaces = "";
        for (uint256 i = 0; i < count; i++) {
            spaces = string.concat(spaces, " ");
        }
        return spaces;
    }
    
    // Function to simulate gas usage in a single block
    function simulateGasUsage(ScenarioData memory scenario) internal {
        console.log("\nSimulating gas usage within a single block...");
        
        // Create transactions for all users in this block
        uint256 blockHeight = block.number;
        console.log("Current block height:", blockHeight);
        
        // Start prank to ensure all transactions happen in the same block
        vm.roll(blockHeight);
        
        for (uint256 i = 0; i < scenario.users.length; i++) {
            User memory user = scenario.users[i];
            
            // Broadcast as the user
            vm.startBroadcast(user.privateKey);
            
            // Call the gas consumer to use gas
            GasConsumer(gasConsumerAddress).consumeGas(user.iterations);
            
            vm.stopBroadcast();
            
            console.log(
                string.concat(
                    "User ", string(abi.encodePacked(bytes1(uint8(65 + i)))),
                    " (", user.tier, ") used gas with ",
                    vm.toString(user.iterations),
                    " iterations"
                )
            );
        }
        
        console.log("All transactions simulated in block:", blockHeight);
    }
}

// Simple contract to consume gas for testing
contract GasConsumer {
    // A variable to store values
    uint256[] public values;
    
    // Function to consume variable amounts of gas
    function consumeGas(uint256 iterations) public {
        // Clear previous values
        delete values;
        
        // Perform computation and storage operations to consume gas
        for (uint256 i = 0; i < iterations; i++) {
            // Push to array (storage operation - expensive)
            if (i % 10 == 0) {
                values.push(i);
            }
            
            // Perform some calculations (CPU operation)
            uint256 result = 0;
            for (uint256 j = 0; j < 5; j++) {
                result += i * j;
            }
            
                            // More expensive storage operation every 100 iterations
            if (i % 100 == 99) {
                values.push(result);
            }
        }
    }
} 
