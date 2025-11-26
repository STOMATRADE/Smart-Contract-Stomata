// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockIDRX
 * @dev Mock Indonesian Rupiah Stablecoin for Testing
 * @notice 1 IDRX = 1 Indonesian Rupiah (IDR)
 * Decimals: 18 (standard ERC20)
 * Example: 1000 IDRX = 1000 * 10^18 = 1000000000000000000000 (in wei)
 */
contract MockIDRX is ERC20, Ownable {
    
    // Events
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    
    /**
     * @dev Constructor untuk deploy MockIDRX
     * @param initialSupply Supply awal dalam IDRX (bukan wei)
     * Example: initialSupply = 1000000 akan mint 1 juta IDRX
     */
    constructor(uint256 initialSupply) 
        ERC20("Indonesian Rupiah X", "IDRX") 
        Ownable(msg.sender) 
    {
        // Mint initial supply ke deployer
        _mint(msg.sender, initialSupply * 10**decimals());
        emit Minted(msg.sender, initialSupply * 10**decimals());
    }
    
    /**
     * @dev Mint token baru (hanya owner)
     * @param to Address penerima
     * @param amount Jumlah IDRX (bukan wei)
     * Example: mint(address, 1000) akan mint 1000 IDRX
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _mint(to, amountInWei);
        emit Minted(to, amountInWei);
    }
    
    /**
     * @dev Burn token dari address tertentu (hanya owner)
     * @param from Address yang akan di-burn tokennya
     * @param amount Jumlah IDRX (bukan wei)
     */
    function burnFrom(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _burn(from, amountInWei);
        emit Burned(from, amountInWei);
    }
    
    /**
     * @dev Burn token sendiri
     * @param amount Jumlah IDRX (bukan wei)
     */
    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 amountInWei = amount * 10**decimals();
        _burn(msg.sender, amountInWei);
        emit Burned(msg.sender, amountInWei);
    }
    
    /**
     * @dev Faucet function - bagi-bagi token gratis untuk testing!
     * Siapa aja bisa claim 10,000 IDRX (sekali doang per address)
     */
    mapping(address => bool) public hasClaimed;
    
    function faucet() external {
        require(!hasClaimed[msg.sender], "Already claimed from faucet");
        require(msg.sender != address(0), "Invalid address");
        
        hasClaimed[msg.sender] = true;
        uint256 faucetAmount = 10000 * 10**decimals(); // 10,000 IDRX
        
        _mint(msg.sender, faucetAmount);
        emit Minted(msg.sender, faucetAmount);
    }
    
    /**
     * @dev Helper function untuk convert IDRX ke Wei
     * @param amountIDRX Jumlah dalam IDRX
     * @return Jumlah dalam Wei
     */
    function toWei(uint256 amountIDRX) public view returns (uint256) {
        return amountIDRX * 10**decimals();
    }
    
    /**
     * @dev Helper function untuk convert Wei ke IDRX
     * @param amountWei Jumlah dalam Wei
     * @return Jumlah dalam IDRX
     */
    function fromWei(uint256 amountWei) public view returns (uint256) {
        return amountWei / 10**decimals();
    }
    
    /**
     * @dev Get balance dalam format IDRX (bukan wei)
     * @param account Address yang mau dicek
     * @return Balance dalam IDRX
     */
    function balanceOfIDRX(address account) external view returns (uint256) {
        return balanceOf(account) / 10**decimals();
    }
}