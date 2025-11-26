// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MockIDRX is ERC20, Ownable {
    
    // Events
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    

    constructor(uint256 initialSupply) 
        ERC20("StableCoin Indonesia", "IDRX") 
        Ownable(msg.sender) 
    {
        // Mint initial supply ke deployer
        _mint(msg.sender, initialSupply * 10**decimals());
        emit Minted(msg.sender, initialSupply * 10**decimals());
    }
    
 
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _mint(to, amountInWei);
        emit Minted(to, amountInWei);
    }

    function burnFrom(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _burn(from, amountInWei);
        emit Burned(from, amountInWei);
    }
    
 
    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _burn(msg.sender, amountInWei);
        emit Burned(msg.sender, amountInWei);
    }
    

    mapping(address => bool) public hasClaimed;
    
    function faucet() external {
        require(!hasClaimed[msg.sender], "Already claimed from faucet");
        require(msg.sender != address(0), "Invalid address");
        
        hasClaimed[msg.sender] = true;
        uint256 faucetAmount = 10000 * 10**decimals(); // 10,000 IDRX
        
        _mint(msg.sender, faucetAmount);
        emit Minted(msg.sender, faucetAmount);
    }

    function toWei(uint256 amountIDRX) public view returns (uint256) {
        return amountIDRX * 10**decimals();
    }
    
 
    function fromWei(uint256 amountWei) public view returns (uint256) {
        return amountWei / 10**decimals();
    }
    
 
    function balanceOfIDRX(address account) external view returns (uint256) {
        return balanceOf(account) / 10**decimals();
    }
}