// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StomaTrade is ERC721, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    enum ProjectStatus {
        PENDING,
        ACTIVE,
        SUCCESS,
        REFUNDING,
        CLOSED
    }

    struct Project {
        uint256 id;
        address projectOwner;
        uint256 valueProject;
        uint256 maxCrowdFunding;
        uint256 totalRaised;
        ProjectStatus status;
    }

    struct Investment {
        uint256 idProject;
        address investor;
        uint256 amount;
    }

    IERC20 public immutable idrx;
    uint256 public nextProjectId = 1;
    uint256 public nextNftId = 1;

    event ProjectCreated(
        uint256 indexed idProject,
        address indexed owner,
        uint256 valueProject,
        uint256 maxCrowdFunding
    );

    event ProjectStatusChanged(
        uint256 indexed idProject,
        ProjectStatus oldStatus,
        ProjectStatus newStatus
    );

    event Invested(
        uint256 indexed idProject,
        address indexed investor,
        uint256 amount,
        uint256 receiptTokenId
    );

    event Refunded(
        uint256 indexed idProject,
        address indexed investor,
        uint256 amount
    );

    event WithDraw(
        uint256 indexed idProject,
        address indexed projectOwner,
        uint256 amount
    );

    event ProfitDeposited(uint256 indexed idProject, uint256 amount);

    event ProfitClaimed(
        uint256 indexed idProject,
        address indexed user,
        uint256 amount
    );

    // ========== STATE VARIABLES ==========
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contribution;
    mapping(uint256 => Investment) public investmentsByTokenId;
    mapping(uint256 => uint256) public profitPool;
    mapping(uint256 => mapping(address => uint256)) public claimedProfit;
    mapping(address => bool) public allowedApprovals;

    // ========== ERRORS ==========
    error InvalidProject();
    error InvalidStatus();
    error ZeroAmount();
    error MaxFundingExceeded();
    error NotProjectOwner();
    error NothingToRefund();
    error NothingToWithdraw();
    error TransferNotAllowed();
    error ApprovalNotAllowed();

    // ========== SBT IMPLEMENTATION ==========
    
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from = address(0))
        // Block transfer (from != address(0) && to != address(0))
        // Allow burning (to = address(0))
        if (from != address(0) && to != address(0)) {
            revert TransferNotAllowed();
        }
        
        return super._update(to, tokenId, auth);
    }

    // ========== CONSTRUCTOR ==========
    
    constructor(address idrxTokenAddress)
        ERC721("Crowdfunding Receipt", "CFR")
        Ownable(msg.sender)
    {
        require(idrxTokenAddress != address(0), "IDRX address empty");
        idrx = IERC20(idrxTokenAddress);
    }

    // ========== MODIFIERS ==========
    
    modifier onlyValidProject(uint256 idProject) {
        if (idProject == 0 || idProject >= nextProjectId) {
            revert InvalidProject();
        }
        _;
    }

    modifier onlyApprovedProjectOwner(uint256 _idProject) {
        Project storage p = projects[_idProject];
        if (!allowedApprovals[p.projectOwner]) {
            revert ApprovalNotAllowed();
        }
        _;
    }

    // ========== PROJECT MANAGEMENT ==========

    function createProject(
        address _projectOwner,
        uint256 _valueProject,
        uint256 _maxCrowdFunding
    ) external onlyOwner returns (uint256 _idProject) {
        if (_maxCrowdFunding == 0) revert ZeroAmount();
        if (_projectOwner == address(0)) {
            _projectOwner = msg.sender;
        }

        _idProject = nextProjectId++;
        projects[_idProject] = Project({
            id: _idProject,
            projectOwner: _projectOwner,
            valueProject: _valueProject,
            maxCrowdFunding: _maxCrowdFunding,
            totalRaised: 0,
            status: ProjectStatus.PENDING
        });

        emit ProjectCreated(
            _idProject,
            _projectOwner,
            _valueProject,
            _maxCrowdFunding
        );
    }

    function approveProject(uint256 _idProject) 
        external
        onlyOwner
        onlyValidProject(_idProject) 
    {
        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.PENDING) revert InvalidStatus();

        allowedApprovals[p.projectOwner] = true;
        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.ACTIVE;
        emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.ACTIVE);
    }

    function setProjectStatus(uint256 _idProject, ProjectStatus newStatus)
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];
        ProjectStatus oldStatus = p.status;
        p.status = newStatus;
        emit ProjectStatusChanged(_idProject, oldStatus, newStatus);
    }

    // ========== INVESTMENT ==========

    function invest(uint256 _idProject, uint256 _amount)
        external
        nonReentrant
        onlyValidProject(_idProject)
        onlyApprovedProjectOwner(_idProject)
    {
        if (_amount == 0) revert ZeroAmount();

        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.ACTIVE) revert InvalidStatus();

        if (p.totalRaised + _amount > p.maxCrowdFunding)
            revert MaxFundingExceeded();

        idrx.safeTransferFrom(msg.sender, address(this), _amount);

        p.totalRaised += _amount;
        contribution[_idProject][msg.sender] += _amount;

        uint256 _NftId = nextNftId++;
        _safeMint(msg.sender, _NftId);

        investmentsByTokenId[_NftId] = Investment({
            idProject: _idProject,
            investor: msg.sender,
            amount: _amount
        });

        emit Invested(_idProject, msg.sender, _amount, _NftId);

        if (
            p.totalRaised == p.maxCrowdFunding &&
            p.status == ProjectStatus.ACTIVE
        ) {
            ProjectStatus oldStatus = p.status;
            p.status = ProjectStatus.SUCCESS;
            emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.SUCCESS);
        }
    }

    // ========== REFUND ==========

    function refundable(uint256 _idProject)
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.ACTIVE && p.status != ProjectStatus.SUCCESS) {
            revert InvalidStatus();
        }

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.REFUNDING;
        emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.REFUNDING);
    }

    function claimRefund(uint256 _idProject)
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.REFUNDING) revert InvalidStatus();

        uint256 _amount = contribution[_idProject][msg.sender];
        if (_amount == 0) revert NothingToRefund();
        contribution[_idProject][msg.sender] = 0;
        p.totalRaised -= _amount;

        idrx.safeTransfer(msg.sender, _amount);
        emit Refunded(_idProject, msg.sender, _amount);
    }

    // ========== WITHDRAWAL ==========

    function withDrawProjectFund(uint256 _idProject)
        external
        nonReentrant
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.SUCCESS) revert InvalidStatus();

        uint256 _amount = p.totalRaised;
        if (_amount == 0) revert NothingToWithdraw();

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.CLOSED;

        idrx.safeTransfer(p.projectOwner, _amount);

        emit WithDraw(_idProject, p.projectOwner, _amount);
        emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.CLOSED);
    }

    // ========== PROFIT DISTRIBUTION ==========

    function depositProfit(uint256 _idProject, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Zero Amount");

        idrx.safeTransferFrom(msg.sender, address(this), _amount);
        profitPool[_idProject] += _amount;
        emit ProfitDeposited(_idProject, _amount);
    }

    function claimProfit(uint256 _idProject)
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];

        if (p.maxCrowdFunding == 0) revert InvalidStatus();
        uint256 userContribution = contribution[_idProject][msg.sender];
        if (userContribution == 0) revert NothingToWithdraw();

        uint256 totalProfit = profitPool[_idProject];
        if (totalProfit == 0) revert NothingToWithdraw();

        if (p.totalRaised == 0) revert InvalidStatus();

        uint256 entitled = (totalProfit * userContribution) / p.totalRaised;

        uint256 already = claimedProfit[_idProject][msg.sender];
        if (entitled <= already) revert NothingToWithdraw();

        uint256 toClaim = entitled - already;

        claimedProfit[_idProject][msg.sender] = entitled;

        idrx.safeTransfer(msg.sender, toClaim);

        emit ProfitClaimed(_idProject, msg.sender, toClaim);
    }

    // ========== VIEW FUNCTIONS ==========

    function getProject(uint256 _idProject)
        external
        view
        onlyValidProject(_idProject)
        returns (
            uint256 id,
            address projectOwner_,
            uint256 valueProject,
            uint256 totalRaised,
            ProjectStatus status
        )
    {
        Project memory p = projects[_idProject];
        return (p.id, p.projectOwner, p.maxCrowdFunding, p.totalRaised, p.status);
    }

    function getClaimableProfit(uint256 _idProject, address _user)
        external
        view
        returns (uint256)
    {
        uint256 userContribution = contribution[_idProject][_user];
        if (userContribution == 0) return 0;

        uint256 totalProfit = profitPool[_idProject];
        if (totalProfit == 0) return 0;

        Project memory p = projects[_idProject];
        if (p.totalRaised == 0) return 0;
        
        uint256 entitled = (totalProfit * userContribution) / p.totalRaised;
        uint256 already = claimedProfit[_idProject][_user];

        return entitled > already ? entitled - already : 0;
    }

    function getInvestmentByNftId(uint256 _NftId)
        external
        view
        returns (Investment memory)
    {
        require(_ownerOf(_NftId) != address(0), "NftId not found");
        return investmentsByTokenId[_NftId];
    }
}