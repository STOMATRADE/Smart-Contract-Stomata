// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// FIX: Menambahkan import eksplisit untuk IERC721 agar dapat digunakan dalam override.
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./ErrorStoma.sol";
import {Event} from "./EventStoma.sol";
import "./StorageStoma.sol";
import "./EnumStoma.sol";

contract StomaTrade is ERC721URIStorage, ReentrancyGuard, Ownable, Event {
    using SafeERC20 for IERC20;
    

    IERC20 public immutable idrx;

    uint256 public nextProjectId = 1;
    uint256 public nextTokenId = 1;

    // ===========================
    // STORAGE
    // ===========================
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contribution;
    mapping(uint256 => Investment) public investmentsByTokenId;
    mapping(uint256 => uint256) public profitPool;
    mapping(uint256 => mapping(address => uint256)) public claimedProfit;
    mapping(address => uint256) public totalInvestment;

    mapping(uint256 => string) public projectCid;
    mapping(uint256 => string) public tokenCid;
    mapping(uint256 => string) public farmerName;

    // ===========================
    // MODIFIER
    // ===========================
    modifier onlyValidProject(uint256 _idProject) {
        if (_idProject == 0 || _idProject >= nextProjectId)
            revert Errors.InvalidProject();
        _;
    }

    // ===========================
    // CONSTRUCTOR
    // ===========================
    constructor(address idrxTokenAddress)
        ERC721("CrowdFunding Stomatrade", "STM")
        // FIX: Removed parentheses from Ownable() to resolve compiler issue.
        Ownable(msg.sender) 
    {
        if (idrxTokenAddress == address(0))
            revert Errors.ZeroAddress();

        idrx = IERC20(idrxTokenAddress);
    }

    // ===========================
    // PROJECT MANAGEMENT
    // ===========================
    function createProject(
        uint256 _valueProject,
        uint256 _maxCrowdFunding,
        string memory _cid,
        address collector,
        uint256 _totalKG,
        uint256 _profitShare,
        uint256 _fee
    ) external onlyOwner returns (uint256 _idProject) {
        if (_maxCrowdFunding == 0 || _valueProject == 0)
            revert Errors.ZeroAmount();
        if (collector == address(0))
            revert Errors.ZeroAddress();

        _idProject = nextProjectId++;

        // Inisialisasi struct Project.
        projects[_idProject] = Project({
            id: _idProject,
            projectOwner: collector,
            valueProject: _valueProject,
            maxCrowdFunding: _maxCrowdFunding,
            totalRaised: 0,
            status: ProjectStatus.ACTIVE,
            profitShare: _profitShare,
            fee: _fee,
            totalKG: _totalKG
        }); 

        if (bytes(_cid).length > 0) {
            projectCid[_idProject] = _cid;
        }

        // Token ini di-mint untuk Project Owner, mungkin untuk representasi Project NFT.
        uint256 nftId = nextTokenId++;
        _safeMint(collector, nftId);

        if (bytes(_cid).length > 0) {
            string memory uri = string(
                abi.encodePacked("https://gateway.pinata.cloud/ipfs/", _cid)
            );
            _setTokenURI(nftId, uri);
            tokenCid[nftId] = _cid;
        }

        emit ProjectCreated(
            _idProject,
            collector,
            _valueProject,
            _maxCrowdFunding,
            _profitShare,
            _fee
        );
    }

    // ===========================
    // FARMER SBT (Soul-Bound Token)
    // ===========================
    function nftFarmer(string memory namaKomoditas) external {
        if (bytes(namaKomoditas).length == 0)
            revert Errors.InvalidInput();

        uint256 nftIdFarmer = nextTokenId++;
        // Mint SBT ke pengirim
        _safeMint(msg.sender, nftIdFarmer);

        farmerName[nftIdFarmer] = namaKomoditas;
        tokenCid[nftIdFarmer] = namaKomoditas;

        emit FarmerMinted(msg.sender, nftIdFarmer, namaKomoditas);
    }

    function setProjectStatus(
        uint256 _idProject,
        ProjectStatus newStatus
    )
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];
        ProjectStatus oldStatus = p.status;

        p.status = newStatus;

        emit ProjectStatusChanged(
            _idProject,
            oldStatus,
            newStatus
        );
    }

    // ===========================
    // INVESTMENT
    // ===========================
    function invest(
        uint256 _idProject,
        uint256 _amount
    )
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        address _investor = msg.sender;

        if (_amount == 0)
            revert Errors.ZeroAmount();

        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.ACTIVE)
            revert Errors.InvalidState();

        if (p.totalRaised + _amount > p.maxCrowdFunding)
            revert Errors.MaxFundingExceeded();

        // Transfer token IDRX dari investor ke kontrak ini
        idrx.safeTransferFrom(_investor, address(this), _amount);

        p.totalRaised += _amount;
        contribution[_idProject][_investor] += _amount;
        totalInvestment[_investor] += _amount;

        // Mint NFT sebagai bukti investasi (SBT Investasi)
        uint256 nftId = nextTokenId++;
        _safeMint(_investor, nftId);

        string memory projectcid = projectCid[_idProject];
        if (bytes(projectcid).length > 0) {
            string memory uri = string(
                abi.encodePacked(
                    "https://gateway.pinata.cloud/ipfs/",
                    projectcid
                )
            );
            _setTokenURI(nftId, uri);
            tokenCid[nftId] = projectcid;
        }

        // Simpan detail investasi yang terhubung dengan NFT ID ini
        investmentsByTokenId[nftId] = Investment({
            idProject: _idProject,
            investor: _investor,
            amount: _amount
        });

        emit Invested(
            _idProject,
            _investor,
            _amount,
            nftId
        );

        // Jika pendanaan tercapai, selesaikan proyek
        if (
            p.totalRaised == p.maxCrowdFunding &&
            p.status == ProjectStatus.ACTIVE
        ) {
            _settleProjectFunding(_idProject);
        }
    }

    // ===========================
    // SETTLEMENT
    // ===========================
    function _settleProjectFunding(uint256 _idProject) internal {
        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.ACTIVE)
            revert Errors.InvalidState();

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.SUCCESS;

        emit ProjectStatusChanged(
            _idProject,
            oldStatus,
            ProjectStatus.SUCCESS
        );

        uint256 amount = p.totalRaised;
        if (amount > 0) {
            // Transfer dana yang terkumpul ke Project Owner
            idrx.safeTransfer(p.projectOwner, amount);
            emit WithDraw(_idProject, p.projectOwner, amount);
        }
    }

    function settleProjectFunding(uint256 _idProject)
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        _settleProjectFunding(_idProject);
    }

    // ===========================
    // REFUND
    // ===========================
    function refundable(uint256 _idProject)
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.ACTIVE)
            revert Errors.InvalidState();

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.REFUNDING;

        emit ProjectStatusChanged(
            _idProject,
            oldStatus,
            ProjectStatus.REFUNDING
        );
    }

    function claimRefund(
        uint256 _idProject,
        address _investor
    )
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        // Pastikan pemanggil adalah investor
        if (msg.sender != _investor)
            revert Errors.Unauthorized();

        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.REFUNDING)
            revert Errors.InvalidState();

        uint256 _amount = contribution[_idProject][_investor];
        if (_amount == 0)
            revert Errors.NothingToRefund();

        // Reset kontribusi dan totalRaised
        contribution[_idProject][_investor] = 0;
        p.totalRaised -= _amount;
        totalInvestment[_investor] -= _amount;

        // Transfer dana kembali ke investor
        idrx.safeTransfer(_investor, _amount);

        emit Refunded(_idProject, _investor, _amount);
    }

    // ===========================
    // PROFIT
    // ===========================
    function depositProfit(
        uint256 _idProject,
        uint256 _amount
    )
        external
        onlyOwner
        onlyValidProject(_idProject)
    {
        if (_amount == 0)
            revert Errors.ZeroAmount();

        if (projects[_idProject].status != ProjectStatus.SUCCESS)
            revert Errors.InvalidState();

        // Transfer profit token dari pemanggil ke kontrak
        idrx.safeTransferFrom(msg.sender, address(this), _amount);
        profitPool[_idProject] += _amount;

        emit ProfitDeposited(_idProject, _amount);
    }

    function claimProfit(uint256 _idProject)
        external
        nonReentrant
        onlyValidProject(_idProject)
    {
        address _investor = msg.sender;
        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.SUCCESS)
            revert Errors.InvalidState();

        uint256 userContribution =
            contribution[_idProject][_investor];
        if (userContribution == 0)
            revert Errors.NothingToWithdraw();

        uint256 totalProfit = profitPool[_idProject];
        if (totalProfit == 0)
            revert Errors.NothingToWithdraw();

        // Hitung bagian profit yang seharusnya didapat
        uint256 entitled =
            (totalProfit * userContribution) / p.totalRaised;

        uint256 already =
            claimedProfit[_idProject][_investor];

        if (entitled <= already)
            revert Errors.NothingToWithdraw();

        uint256 payableProfit = entitled - already;

        // Update state
        claimedProfit[_idProject][_investor] += payableProfit;
        profitPool[_idProject] -= payableProfit;

        // Transfer profit
        idrx.safeTransfer(_investor, payableProfit);

        emit ProfitClaimed(
            _idProject,
            _investor,
            payableProfit
        );
    }

    // ===========================
    // SBT PROTECTION: Mencegah transfer dan persetujuan (approve/setApprovalForAll)
    // ===========================
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721) returns (address) {
        address from = _ownerOf(tokenId); 
        
        if (from != address(0) && to != address(0)) {
            revert("FarmerNFT cannot be transferred.");
        }

        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256)
        public
        virtual
        // FIX: Override ganda dari ERC721 dan IERC721
        override(ERC721, IERC721)
    {
        revert Errors.ApprovalNotAllowed();
    }

    function setApprovalForAll(address, bool)
        public
        virtual
        // FIX: Override ganda dari ERC721 dan IERC721
        override(ERC721, IERC721)
    {
        revert Errors.ApprovalNotAllowed();
    }

    // ===========================
    // VIEW
    // ===========================
    function getTotalInvestment(address _investor)
        external
        view
        returns (uint256)
    {
        return totalInvestment[_investor];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override // Override dari ERC721URIStorage
        returns (string memory)
    {
        // Pengecekan keberadaan token. _exists masih benar dan digunakan secara internal.
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");

        string memory _cid = tokenCid[tokenId];
        if (bytes(_cid).length == 0)
            revert Errors.InvalidInput();

        return string(
            abi.encodePacked(
                "https://gateway.pinata.cloud/ipfs/",
                _cid
            )
        );
    }

    

    function getProject(uint256 _idProject)
        external
        view
        onlyValidProject(_idProject)
        returns (
            uint256 id,
            address projectOwner,
            uint256 valueProject,
            uint256 totalRaised,
            ProjectStatus status,
            uint256 profitShare,
            uint256 fee,
            uint256 totalKG
        )
    {
        Project memory p = projects[_idProject];
        return (
            p.id,
            p.projectOwner,
            p.valueProject,
            p.totalRaised,
            p.status,
            p.profitShare,
            p.fee,
            p.totalKG
        );
    }

    function getClaimableProfit(
        uint256 _idProject,
        address _investor
    )
        external
        view
        returns (uint256)
    {
        uint256 userContribution =
            contribution[_idProject][_investor];
        if (userContribution == 0) return 0;

        uint256 totalProfit = profitPool[_idProject];
        if (totalProfit == 0) return 0;

        Project memory p = projects[_idProject];
        if (p.totalRaised == 0) return 0;

        uint256 entitled =
            (totalProfit * userContribution) / p.totalRaised;

        uint256 already =
            claimedProfit[_idProject][_investor];

        return entitled > already
            ? entitled - already
            : 0;
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