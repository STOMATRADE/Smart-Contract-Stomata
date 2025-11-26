// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StomaTrade.sol";
import "../src/MockIDRX.sol";

contract DeployScript is Script {
    function run() external {
        // Get private key dari environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYMENT START ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MockIDRX dengan 10 juta supply
        // Note: Jangan dikali decimals, constructor MockIDRX sudah handle
        MockIDRX idrx = new MockIDRX(10_000_000);
        console.log("\n[1/2] MockIDRX deployed at:", address(idrx));
        console.log("      Total Supply:", idrx.totalSupply() / 10**18, "IDRX");
        console.log("      Deployer Balance:", idrx.balanceOfIDRX(deployer), "IDRX");
        
        // 2. Deploy StomaTrade
        StomaTrade stoma = new StomaTrade(address(idrx));
        console.log("\n[2/2] StomaTrade deployed at:", address(stoma));
        console.log("      IDRX Token:", address(idrx));
        
        // 3. Optional: Transfer ownership ke address lain
        // stoma.transferOwnership(NEW_OWNER_ADDRESS);
        // idrx.transferOwnership(NEW_OWNER_ADDRESS);
        
        vm.stopBroadcast();
        
        // Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", getNetworkName(block.chainid));
        console.log("Deployer:", deployer);
        console.log("MockIDRX:", address(idrx));
        console.log("StomaTrade:", address(stoma));
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Update frontend config with contract addresses");
        console.log("3. Test createProject and approveProject functions");
        console.log("\n=== VERIFY COMMANDS ===");
        console.log("MockIDRX:");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(idrx)),
            " MockIDRX --chain-id ",
            vm.toString(block.chainid),
            " --constructor-args $(cast abi-encode 'constructor(uint256)' 10000000)"
        ));
        console.log("\nStomaTrade:");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(stoma)),
            " StomaTrade --chain-id ",
            vm.toString(block.chainid),
            " --constructor-args $(cast abi-encode 'constructor(address)' ",
            vm.toString(address(idrx)),
            ")"
        ));
    }
    
    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "Ethereum Mainnet";
        if (chainId == 11155111) return "Sepolia Testnet";
        if (chainId == 4202) return "Lisk Sepolia Testnet";
        if (chainId == 31337) return "Localhost/Anvil";
        return "Unknown Network";
    }
}