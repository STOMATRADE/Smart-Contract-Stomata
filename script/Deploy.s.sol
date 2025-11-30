// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/MainStoma.sol";
import "../src/MockIDRX.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==============================================");
        console.log("Deployer Address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("==============================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockIDRX token
        MockIDRX idrx = new MockIDRX(1_000_000 ether);
        console.log("MockIDRX deployed at:", address(idrx));

        // Deploy StomaTrade dengan IDRX token address
        StomaTrade stoma = new StomaTrade(address(idrx));
        console.log("StomaTrade deployed at:", address(stoma));

        vm.stopBroadcast();

        console.log("\n==============================================");
        console.log("       VERIFY CONTRACT COMMANDS");
        console.log("==============================================\n");

        // Verify IDRX
        verify(
            "IDRX",
            address(idrx),
            "src/MockIDRX.sol:MockIDRX",
            abi.encode(1_000_000 ether)
        );

        // Verify StomaTrade - ✅ FIXED: gunakan address(idrx) bukan deployer
        verify(
            "STOMATRADE",
            address(stoma),
            "src/MainStoma.sol:StomaTrade",
            abi.encode(address(idrx))
        );
    }

    function verify(
        string memory name,
        address contractAddress,
        string memory path,
        bytes memory args
    ) internal view {
        console.log(
            string.concat(
                "[VERIFY] ",
                name,
                ": forge verify-contract ",
                vm.toString(contractAddress),
                " ",
                path,
                " --verifier blockscout",
                " --verifier-url https://sepolia-blockscout.lisk.com/api",
                " --constructor-args ",
                vm.toString(args),
                " --chain-id ",
                vm.toString(block.chainid),
                " --watch"
            )
        );
    }
}