// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/MainStoma.sol";
import "../src/MockIDRX.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockIDRX token
        MockIDRX idrx = new MockIDRX(1_000_000); // initial supply 1,000,000 IDRX

        // Deploy StomaTrade dengan IDRX token address
        StomaTrade stoma = new StomaTrade(address(idrx));

        vm.stopBroadcast();
        console.log("\n=========================================");
        console.log("          VERIFY CONTRACT COMMANDS");
        console.log("=========================================");

        uint256 chainId = block.chainid;

        verify("IDRX", address(idrx), "src/MockIDRX.sol:MockIDRX", abi.encode(1_000_000));
        verify("STOMATRADE", address(stoma), "src/MainStoma.sol:StomaTrade", abi.encode(deployer));
        
    }
 
    function verify(string memory name, address c, string memory path, bytes memory args) internal view {
            console.log(
                string.concat(
                    "[VERIFY] ", name,
                    ": forge verify-contract ",
                    vm.toString(c),
                    " ", path,
                    " --verifier blockscout",
                    " --verifier-url https://sepolia-blockscout.lisk.com/api",
                    " --constructor-args ", vm.toString(args),
                    " --chain-id ", vm.toString(block.chainid),
                    " --watch"
                )
            );
        }

}
