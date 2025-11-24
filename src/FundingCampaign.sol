// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IStomaSBT {
    function mintInvestor(
        address investor, 
        bytes32 campaignId, 
        uint256 amount, 
        string calldata metadataUri
    ) external returns (uint256);
}

/**
 * @title FundingCampaign
 * @notice Crowdfunding campaign contract (on-chain minimal, off-chain metadata)
 */
contract FundingCampaign is ReentrancyGuard, Ownable, Pausable {

    enum CampaignState { FUNDING, ACTIVE, COMPLETED, FAILED }

    // ═══════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════

    bytes32 public campaignId;
    address public collector;
    uint256 public crowdfundingTarget;
    string public metadataCID;

    CampaignState public state;

    IERC20 public immutable USDT;
    IStomaSBT public sbt;

    mapping(address => uint256) public contributions;
    address[] public lenders;
    mapping(address => bool) public isLender;
    mapping(address => bool) public hasClaimed;

    // ═══════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════
    
    event CampaignActivated(uint256 timestamp);
    event CampaignCompleted(uint256 timestamp);
    event CampaignFailed(uint256 timestamp);
    event Deposited(address indexed lender, uint256 amount, uint256 totalRaised, uint256 timestamp, uint256 tokenId);
    event FundsWithdrawnToCollector(address indexed collector, uint256 amount, uint256 timestamp);
    event ReturnsDeposited(uint256 totalToDeposit, uint256 timestamp);
    event ReturnsClaimed(address indexed lender, uint256 principal, uint256 profit, uint256 total, uint256 timestamp);
    event RefundClaimed(address indexed lender, uint256 amount, uint256 timestamp);

    // ═══════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════
    
    constructor(
        address _usdt,
        address _sbt,
        bytes32 _campaignId,
        address _collector,
        uint256 _crowdfundingTarget,
        string memory _metadataCID
    ) Ownable(msg.sender) {
        require(_usdt != address(0) && _sbt != address(0), "Invalid addresses");
        require(_collector != address(0), "Invalid collector");

        USDT = IERC20(_usdt);
        sbt = IStomaSBT(_sbt);

        campaignId = _campaignId;
        collector = _collector;
        crowdfundingTarget = _crowdfundingTarget;
        metadataCID = _metadataCID;

        state = CampaignState.FUNDING;
    }

    // ═══════════════════════════════════
    // EXTERNAL FUNCTIONS - CROWDFUNDING
    // ═══════════════════════════════════

    function deposit(uint256 amount, string calldata metadataUri)
        external
        nonReentrant
        whenNotPaused
    {
        require(state == CampaignState.FUNDING, "Not in funding state");
        require(amount > 0, "Amount must > 0");

        require(USDT.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");

        if (!isLender[msg.sender]) {
            isLender[msg.sender] = true;
            lenders.push(msg.sender);
        }

        contributions[msg.sender] += amount;

        uint256 tokenId = sbt.mintInvestor(msg.sender, campaignId, amount, metadataUri);

        emit Deposited(msg.sender, amount, contributions[msg.sender], block.timestamp, tokenId);

        // Active state jika sudah mencapai target
        if (totalRaised() >= crowdfundingTarget) {
            state = CampaignState.ACTIVE;
            emit CampaignActivated(block.timestamp);
        }
    }

    function withdrawFundsToCollector(uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(state == CampaignState.FUNDING || state == CampaignState.ACTIVE, "Wrong state");
        require(amount <= totalRaised(), "Not enough funds");

        state = CampaignState.ACTIVE;

        require(USDT.transfer(collector, amount), "Transfer failed");

        emit FundsWithdrawnToCollector(collector, amount, block.timestamp);
    }

    function markFailed() external onlyOwner {
        require(state == CampaignState.FUNDING, "Can only fail from FUNDING");
        state = CampaignState.FAILED;
        emit CampaignFailed(block.timestamp);
    }

    function claimRefund() external nonReentrant {
        require(state == CampaignState.FAILED, "Campaign not failed");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;

        require(USDT.transfer(msg.sender, amount), "Refund transfer failed");

        emit RefundClaimed(msg.sender, amount, block.timestamp);
    }

    function depositReturns() external onlyOwner nonReentrant {
        require(state == CampaignState.ACTIVE, "Campaign not active");

        uint256 totalToDeposit = totalRaised(); // On-chain minimal, profit bisa dihitung off-chain

        require(USDT.transferFrom(msg.sender, address(this), totalToDeposit), "TransferFrom failed");

        state = CampaignState.COMPLETED;
        emit ReturnsDeposited(totalToDeposit, block.timestamp);
        emit CampaignCompleted(block.timestamp);
    }

    function claimReturns() external nonReentrant {
        require(state == CampaignState.COMPLETED, "Not completed");
        require(!hasClaimed[msg.sender], "Already claimed");

        uint256 principal = contributions[msg.sender];
        require(principal > 0, "No contribution");

        hasClaimed[msg.sender] = true;

        require(USDT.transfer(msg.sender, principal), "Transfer failed");

        emit ReturnsClaimed(msg.sender, principal, 0, principal, block.timestamp);
    }

    // ═══════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════

    function totalRaised() public view returns (uint256 total) {
        for (uint i = 0; i < lenders.length; i++) {
            total += contributions[lenders[i]];
        }
    }

    function getLenders() external view returns (address[] memory) {
        return lenders;
    }

    // ═══════════════════════════════════
    // EMERGENCY FUNCTIONS
    // ═══════════════════════════════════

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
