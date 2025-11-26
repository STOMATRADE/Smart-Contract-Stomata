// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./ErrorStoma.sol";
import {Event} from "./EventStoma.sol";
import "./StorageStoma.sol";
import "./EnumStoma.sol" ;


contract StomaTrade is ERC721URIStorage, ReentrancyGuard, Ownable , Event {
    using SafeERC20 for IERC20;

    IERC20 public immutable idrx;
    uint256 public nextProjectId = 1;
    uint256 public nextNftId = 1;
    uint256 public nextFarmerId = 1 ;

    // STATE
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contribution;
    mapping(uint256 => Investment) public investmentsByTokenId;
    mapping(uint256 => uint256) public profitPool;
    mapping(uint256 => mapping(address => uint256)) public claimedProfit;
    mapping(address => uint256) public totalInvestment;
    mapping(uint256 => string) public tokenCid; 

    // MODIFIERS
    modifier onlyValidProject(uint256 _idProject) {
        if (_idProject == 0 || _idProject >= nextProjectId) revert Errors.InvalidProject();
        _;
    }

    // CONSTRUCTOR 
    constructor(address idrxTokenAddress)
        ERC721("CrowdFunding Stomatrade", "STM")
        Ownable(msg.sender)
    {
        if (idrxTokenAddress == address(0)) revert Errors.ZeroAddress();
        idrx = IERC20(idrxTokenAddress);
    }

    // PROJECT MANAGEMENT 
    function createProject(
    uint256 _valueProject,
    uint256 _maxCrowdFunding,
    string memory _cid
    ) external returns (uint256 _idProject) {
    if (_maxCrowdFunding == 0) revert Errors.ZeroAmount();
    if (msg.sender == address(0)) revert Errors.ZeroAddress(); 

    // Assign ID project
    _idProject = nextProjectId++;

    // Simpan project langsung dengan status ACTIVE
    projects[_idProject] = Project({
        id: _idProject,
        projectOwner: msg.sender,
        valueProject: _valueProject,
        maxCrowdFunding: _maxCrowdFunding,
        totalRaised: 0,
        status: ProjectStatus.ACTIVE
    });

    tokenCid[_idProject] = _cid;

    // MINT Project SBT ke project owner
    uint256 nftId = nextNftId++;
    _safeMint(msg.sender, nftId); // pakai msg.sender langsung

    if (bytes(_cid).length > 0) {
        string memory uri = string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", _cid));
        _setTokenURI(nftId, uri);
    }

    emit ProjectCreated(_idProject, msg.sender, _valueProject, _maxCrowdFunding);
}


    // FARMER SBT 
    function nftFarmer(string memory namaKomoditas) external {
        uint256 nftIdFarmer = nextFarmerId++;
        _safeMint(msg.sender, nftIdFarmer);
        tokenCid[nftIdFarmer] = namaKomoditas;

        emit FarmerMinted(msg.sender, nftIdFarmer, namaKomoditas);
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

    // INVESTMENT 
    function invest(uint256 _idProject, uint256 _amount)
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        if (_amount == 0) revert Errors.ZeroAmount();

        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.ACTIVE) revert Errors.InvalidState();
        if (p.totalRaised + _amount > p.maxCrowdFunding) revert Errors.MaxFundingExceeded();

        idrx.safeTransferFrom(msg.sender, address(this), _amount);

        p.totalRaised += _amount;
        contribution[_idProject][msg.sender] += _amount;
        totalInvestment[msg.sender] += _amount; 

        // akan ngeminting sbt
        uint256 nftId = nextNftId++;
        _safeMint(msg.sender, nftId);

        string memory projectCid = tokenCid[_idProject];
        if (bytes(projectCid).length > 0) {
            string memory uri = string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", projectCid));
            _setTokenURI(nftId, uri);
        }
        tokenCid[nftId] = projectCid;

        investmentsByTokenId[nftId] = Investment({
            idProject: _idProject,
            investor: msg.sender,
            amount: _amount
        });

        emit Invested(_idProject, msg.sender, _amount, nftId);

        if (p.totalRaised == p.maxCrowdFunding && p.status == ProjectStatus.ACTIVE) {
            _settleProjectFunding(_idProject);
        }
    }

    // DARI DANA CROWDFUNDING ITU KE COLLECTOR (PROJECTOWNER)
    function _settleProjectFunding(uint256 _idProject) internal {
        Project storage p = projects[_idProject];
        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.SUCCESS;
        emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.SUCCESS);

        uint256 amount = p.totalRaised;
        if (amount > 0) {
            idrx.safeTransfer(p.projectOwner, amount);
            emit WithDraw(_idProject, p.projectOwner, amount);
        }
    }

    // REFUND 
    function refundable(uint256 _idProject)
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.ACTIVE && p.status != ProjectStatus.SUCCESS) revert Errors.InvalidState();

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
        if (p.status != ProjectStatus.REFUNDING) revert Errors.InvalidState();

        uint256 _amount = contribution[_idProject][msg.sender];
        if (_amount == 0) revert Errors.NothingToRefund();

        contribution[_idProject][msg.sender] = 0;
        p.totalRaised -= _amount;
        totalInvestment[msg.sender] -= _amount; 

        idrx.safeTransfer(msg.sender, _amount);
        emit Refunded(_idProject, msg.sender, _amount);
    }

    // PROFIT 
    function depositProfit(uint256 _idProject, uint256 _amount) 
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        if (_amount == 0) revert Errors.ZeroAmount();
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
        if (p.maxCrowdFunding == 0) revert Errors.InvalidState();

        uint256 userContribution = contribution[_idProject][msg.sender];
        if (userContribution == 0) revert Errors.NothingToWithdraw();

        uint256 totalProfit = profitPool[_idProject];
        if (totalProfit == 0) revert Errors.NothingToWithdraw();
        if (p.totalRaised == 0) revert Errors.InvalidState();

        uint256 entitled = (totalProfit * userContribution) / p.totalRaised;
        uint256 already = claimedProfit[_idProject][msg.sender];
        if (entitled <= already) revert Errors.NothingToWithdraw();

        uint256 toClaim = entitled - already;
        claimedProfit[_idProject][msg.sender] = entitled;

        idrx.safeTransfer(msg.sender, toClaim);
        emit ProfitClaimed(_idProject, msg.sender, toClaim);
    }

    // VIEW 
    function getTotalInvestment(address _user) external view returns (uint256) {
        return totalInvestment[_user];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (_ownerOf(tokenId) == address(0)) revert Errors.InvalidInput();
        
        string memory _cid = tokenCid[tokenId];
        if (bytes(_cid).length == 0) revert Errors.InvalidInput(); 
        
        // Menggunakan skema IPFS standar
        return string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", _cid));
    }

    function getProject(uint256 _idProject)
        external
        view
        onlyValidProject(_idProject)
        returns (
            uint256 id,
            address projectOwner_,
            uint256 valueProject_,
            uint256 totalRaised_,
            ProjectStatus status_
        )
    {
        Project memory p = projects[_idProject];
        return (p.id, p.projectOwner, p.valueProject, p.totalRaised, p.status);
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

        // Proporsi keuntungan yang berhak diterima user
        uint256 entitled = (totalProfit * userContribution) / p.totalRaised;
        uint256 already = claimedProfit[_idProject][_user];

        return entitled > already ? entitled - already : 0;
    }

    function getInvestmentByNftId(uint256 _NftId)
        external
        view
        returns (Investment memory)
    {
        if (_ownerOf(_NftId) == address(0)) revert Errors.InvalidProject();
        return investmentsByTokenId[_NftId];
    }
}