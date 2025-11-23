// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FundingCampaign.sol";

/**
 * @title CampaignFactory
 * @notice Factory untuk create & track campaigns
 * @dev Only admin can create campaigns
 */
 // ini edit baru dehhh
contract CampaignFactory is Ownable {
    
    // ═══════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════
    
    address public immutable usdtToken;
    address public farmerRegistry;
    address public buyerRegistry;
    
    address[] public campaigns;
    mapping(address => bool) public isCampaign;
    uint256 public campaignCount;
    
    // ═══════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════
    
    event CampaignCreated(
        address indexed campaignAddress,
        bytes32 indexed campaignId,
        bytes32[] farmerIds,
        bytes32 indexed buyerId,
        uint256 crowdfundingTarget,
        uint256 totalProjectValue,
        uint256 timestamp
    );
    
    // ═══════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════
    
    constructor(
        address _usdtToken,
        address _farmerRegistry,
        address _buyerRegistry
    ) Ownable(msg.sender) {
        require(_usdtToken != address(0), "Invalid USDT");
        require(_farmerRegistry != address(0), "Invalid farmer registry");
        require(_buyerRegistry != address(0), "Invalid buyer registry");
        
        usdtToken = _usdtToken;
        farmerRegistry = _farmerRegistry;
        buyerRegistry = _buyerRegistry;
    }
    
    // ═══════════════════════════════════════════════════════
    // EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════
    
    /**
     * @notice Create new campaign
     * @dev Only admin can create
     */
    function createCampaign(
        bytes32 _campaignId,
        bytes32[] calldata _farmerIds,
        uint256[] calldata _allocatedWeights,
        bytes32 _buyerId,
        address _collector,
        FundingCampaign.CommodityType _commodity,
        uint256 _totalProjectValue,
        uint256 _stomatradeContribution,
        uint256 _crowdfundingTarget,
        uint256 _profitPerKg,
        uint256 _lenderShareBPS,
        uint256 _fundingDuration
    ) 
        external 
        onlyOwner 
        returns (address) 
    {
        require(_farmerIds.length > 0, "Need farmers");
        require(_farmerIds.length == _allocatedWeights.length, "Length mismatch");
        
        // Validate farmers exist (bisa dipanggil via interface)
        // For simplicity, kita skip validation di sini
        // Di production, harus validate via IFarmerRegistry interface
        
        // Deploy new campaign
        FundingCampaign campaign = new FundingCampaign(
            usdtToken,
            _campaignId,
            _farmerIds,
            _allocatedWeights,
            _buyerId,
            _collector,
            _commodity,
            _totalProjectValue,
            _stomatradeContribution,
            _crowdfundingTarget,
            _profitPerKg,
            _lenderShareBPS,
            _fundingDuration
        );
        
        address campaignAddress = address(campaign);
        
        campaigns.push(campaignAddress);
        isCampaign[campaignAddress] = true;
        campaignCount++;
        
        emit CampaignCreated(
            campaignAddress,
            _campaignId,
            _farmerIds,
            _buyerId,
            _crowdfundingTarget,
            _totalProjectValue,
            block.timestamp
        );
        
        return campaignAddress;
    }
    
    // ═══════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════
    
    /**
     * @notice Get all campaigns
     */
    function getAllCampaigns() 
        external 
        view 
        returns (address[] memory) 
    {
        return campaigns;
    }
    
    /**
     * @notice Get campaign by index
     */
    function getCampaign(uint256 index) 
        external 
        view 
        returns (address) 
    {
        require(index < campaigns.length, "Index out of bounds");
        return campaigns[index];
    }
    
    /**
     * @notice Get latest campaign
     */
    function getLatestCampaign() 
        external 
        view 
        returns (address) 
    {
        require(campaigns.length > 0, "No campaigns");
        return campaigns[campaigns.length - 1];
    }
}