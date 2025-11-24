// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDT is ERC20, Ownable {
    constructor() ERC20("Mock USDT", "USDT") Ownable(msg.sender) {
        // Mint 10 juta USDT untuk testing (10,000,000 USDT)
        _mint(msg.sender, 10_000_000 * 10**6);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function toWei(uint256 amount) external pure returns (uint256) {
        return amount * 10**6;
    }

    function fromWei(uint256 weiAmount) external pure returns (uint256) {
        return weiAmount / 10**6;
    }
}