// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StomaMultiSBT
 * @notice Soulbound Token for STOMATRADE (Farmers, Investors, Projects)
 */
contract StomaMultiSBT is ERC721, Ownable {
    
    // ═══════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════
    
    uint256 private _nextTokenId = 1;

    enum TokenType { NONE, FARMER, INVESTOR, PROJECT }

    address public custodian;
    address public factory;
    mapping(address => bool) public isCampaignMinter;

    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => TokenType) public tokenTypeOf;

    // Farmer mappings (revisi ke uint256)
    mapping(uint256 => uint256) public farmerIdToToken;
    mapping(uint256 => uint256) public farmerToCollector;

    // Investor mappings
    struct InvestorRecord {
        uint256 tokenId;
        address investor;
        bytes32 campaignId;
        uint256 amount;
        uint256 mintedAt;
    }
    mapping(uint256 => InvestorRecord) public investorRecords;
    mapping(address => uint256[]) public investorTokenIds;

    // Project mappings
    mapping(bytes32 => uint256) public campaignToProjectToken;

    // ═══════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════
    
    event CustodianSet(address indexed custodian);
    event FactorySet(address indexed factory);
    event CampaignMinterSet(address indexed minter, bool allowed);

    event FarmerRegistered(
        uint256 indexed tokenId, 
        uint256 indexed farmerId, 
        uint256 indexed collectorId, 
        string metadataURI
    );
    event FarmerBurned(uint256 indexed tokenId, uint256 indexed farmerId);

    event InvestorMinted(
        uint256 indexed tokenId, 
        address indexed investor, 
        bytes32 indexed campaignId, 
        uint256 amount, 
        string metadataURI
    );
    event InvestorBurned(uint256 indexed tokenId, address indexed investor);

    event ProjectMinted(
        uint256 indexed tokenId, 
        bytes32 indexed campaignId, 
        string metadataURI
    );
    event ProjectBurned(uint256 indexed tokenId, bytes32 indexed campaignId);

    // ═══════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════
    
    constructor(
        string memory name_, 
        string memory symbol_, 
        address _custodian
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(_custodian != address(0), "Invalid custodian");
        custodian = _custodian;
        emit CustodianSet(_custodian);
    }

    // ═══════════════════════════════════════════════════════
    // ADMIN SETTINGS
    // ═══════════════════════════════════════════════════════
    
    function setCustodian(address _custodian) external onlyOwner {
        require(_custodian != address(0), "Invalid custodian");
        custodian = _custodian;
        emit CustodianSet(_custodian);
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
        emit FactorySet(_factory);
    }

    function setCampaignMinter(address _minter, bool allowed) external onlyOwner {
        isCampaignMinter[_minter] = allowed;
        emit CampaignMinterSet(_minter, allowed);
    }

    // ═══════════════════════════════════════════════════════
    // FARMER SBT (mint to custodian)
    // ═══════════════════════════════════════════════════════
    
    function registerFarmer(
        uint256 farmerId, 
        uint256 collectorId, 
        string calldata metadataUri
    ) external onlyOwner returns (uint256) {
        require(farmerId != 0, "Invalid farmerId");
        require(farmerIdToToken[farmerId] == 0, "Farmer already exists");

        uint256 tid = _nextTokenId++;
        _safeMint(custodian, tid);

        tokenTypeOf[tid] = TokenType.FARMER;
        _tokenURI[tid] = metadataUri;
        farmerIdToToken[farmerId] = tid;
        farmerToCollector[farmerId] = collectorId;

        emit FarmerRegistered(tid, farmerId, collectorId, metadataUri);
        return tid;
    }

    function burnFarmer(uint256 farmerId) external onlyOwner {
        uint256 tid = farmerIdToToken[farmerId];
        require(tid != 0, "Farmer not found");
        
        _burn(tid);
        
        delete farmerIdToToken[farmerId];
        delete farmerToCollector[farmerId];
        delete _tokenURI[tid];
        tokenTypeOf[tid] = TokenType.NONE;
        
        emit FarmerBurned(tid, farmerId);
    }

    // ═══════════════════════════════════════════════════════
    // INVESTOR SBT (mint by campaign)
    // ═══════════════════════════════════════════════════════
    
    function mintInvestor(
        address investor, 
        bytes32 campaignId, 
        uint256 amount, 
        string calldata metadataUri
    ) external returns (uint256) {
        require(isCampaignMinter[msg.sender], "Not authorized minter");
        require(investor != address(0), "Invalid investor");
        require(amount > 0, "Amount must be > 0");

        uint256 tid = _nextTokenId++;
        _safeMint(investor, tid);

        tokenTypeOf[tid] = TokenType.INVESTOR;
        _tokenURI[tid] = metadataUri;

        investorRecords[tid] = InvestorRecord({
            tokenId: tid,
            investor: investor,
            campaignId: campaignId,
            amount: amount,
            mintedAt: block.timestamp
        });
        investorTokenIds[investor].push(tid);

        emit InvestorMinted(tid, investor, campaignId, amount, metadataUri);
        return tid;
    }

    function burnInvestor(uint256 tokenId) external onlyOwner {
        require(tokenTypeOf[tokenId] == TokenType.INVESTOR, "Not investor token");
        address holder = ownerOf(tokenId);
        
        _burn(tokenId);

        delete investorRecords[tokenId];
        tokenTypeOf[tokenId] = TokenType.NONE;
        delete _tokenURI[tokenId];

        emit InvestorBurned(tokenId, holder);
    }

    // ═══════════════════════════════════════════════════════
    // PROJECT SBT (mint by factory)
    // ═══════════════════════════════════════════════════════
    
    function mintProject(
        address to, 
        bytes32 campaignId, 
        string calldata metadataUri
    ) external returns (uint256) {
        require(msg.sender == factory, "Only factory can mint");
        require(campaignToProjectToken[campaignId] == 0, "Project already exists");

        uint256 tid = _nextTokenId++;
        _safeMint(to, tid);

        tokenTypeOf[tid] = TokenType.PROJECT;
        _tokenURI[tid] = metadataUri;
        campaignToProjectToken[campaignId] = tid;

        emit ProjectMinted(tid, campaignId, metadataUri);
        return tid;
    }

    function burnProjectByCampaign(bytes32 campaignId) external onlyOwner {
        uint256 tid = campaignToProjectToken[campaignId];
        require(tid != 0, "Project not found");
        
        _burn(tid);
        
        delete campaignToProjectToken[campaignId];
        delete _tokenURI[tid];
        tokenTypeOf[tid] = TokenType.NONE;
        
        emit ProjectBurned(tid, campaignId);
    }

    // ═══════════════════════════════════════════════════════
    // TOKEN URI OVERRIDE
    // ═══════════════════════════════════════════════════════
    
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenURI[tokenId];
    }

    // ═══════════════════════════════════════════════════════
    // SOULBOUND: PREVENT TRANSFERS
    // ═══════════════════════════════════════════════════════
    
    function _update(
        address to, 
        uint256 tokenId, 
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        if (from != address(0) && to != address(0)) {
            revert("SBT: Soulbound - non-transferable");
        }
        
        return super._update(to, tokenId, auth);
    }

    // ═══════════════════════════════════════════════════════
    // GETTERS
    // ═══════════════════════════════════════════════════════
    
    function getInvestorTokenIds(address investor) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return investorTokenIds[investor];
    }

    function getInvestorRecord(uint256 tokenId) 
        external 
        view 
        returns (InvestorRecord memory) 
    {
        require(tokenTypeOf[tokenId] == TokenType.INVESTOR, "Not investor token");
        return investorRecords[tokenId];
    }

    function getFarmerTokenById(uint256 farmerId) 
        external 
        view 
        returns (uint256) 
    {
        return farmerIdToToken[farmerId];
    }

    function getProjectTokenByCampaign(bytes32 campaignId) 
        external 
        view 
        returns (uint256) 
    {
        return campaignToProjectToken[campaignId];
    }
    
    function getTotalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
}
