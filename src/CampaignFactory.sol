// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FundingCampaign.sol";

// ✅ FIX: Remove duplicate interface - sudah ada di FundingCampaign.sol
// Interface hanya perlu di satu tempat

contract CampaignFactory is Ownable {
    address public usdtToken;
    address public sbt;
    address[] public campaigns;

    event CampaignCreated(
        address indexed campaignAddress, 
        bytes32 indexed campaignId, 
        address collector, 
        uint256 crowdfundingTarget
    );

    constructor(address _usdt, address _sbt) Ownable(msg.sender) {
        require(_usdt != address(0) && _sbt != address(0), "Invalid addresses");
        usdtToken = _usdt;
        sbt = _sbt;
    }

  function createCampaign(
    bytes32 _campaignId,
    address _collector,
    uint256 _crowdfundingTarget,
    string calldata _metadataCID
) external onlyOwner returns (address) {

    FundingCampaign campaign = new FundingCampaign(
        usdtToken,
        sbt,
        _campaignId,
        _collector,
        _crowdfundingTarget,
        _metadataCID
    );

    address campaignAddr = address(campaign);
    campaigns.push(campaignAddr);

    // Set campaign minter di SBT
    (bool success, ) = sbt.call(
        abi.encodeWithSignature("setCampaignMinter(address,bool)", campaignAddr, true)
    );
    require(success, "Failed to set campaign minter");

    // Mint project SBT
    (bool success2, ) = sbt.call(
        abi.encodeWithSignature("mintProject(address,bytes32,string)",
            owner(), _campaignId, _metadataCID)
    );
    require(success2, "Failed to mint project");

    emit CampaignCreated(campaignAddr, _campaignId, _collector, _crowdfundingTarget);
    return campaignAddr;
}


    function getAllCampaigns() external view returns (address[] memory) {
        return campaigns;
    }
    
    function getCampaignCount() external view returns (uint256) {
        return campaigns.length;
    }
}