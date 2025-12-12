// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable as OZOwnable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ProjectStorage} from "./utils/ProjectStorage.sol";
import {FarmerStorage} from "./utils/FarmerStorage.sol";
import {Event} from "./utils/Event.sol";
import {Constant} from "./utils/Constant.sol";

import {Errors} from "./utils/Errors.sol";
import {ProjectStatus, InvestmentStatus} from "./utils/Enum.sol";

contract Stomatrade is
    ERC721URIStorage,
    ReentrancyGuard,
    OZOwnable,
    ProjectStorage,
    FarmerStorage,
    Event,
    Constant
{
    using SafeERC20 for IERC20;
    IERC20 public immutable IDRX;
    uint256 public idToken = 1;

    constructor(
        address idrxTokenAddress
    ) ERC721("Stomatrade", "STMX") OZOwnable(msg.sender) {
        if (idrxTokenAddress == address(0)) revert Errors.ZeroAddress();
        IDRX = IERC20(idrxTokenAddress);
    }

    function addFarmer(
        string memory _cid,
        string memory _idCollector,
        string memory _name,
        uint256 _age,
        string memory _domicile
    ) external onlyOwner returns (uint256 _idFarmer) {
        ++idToken;
        _idFarmer = ++idFarmer;

        farmers[_idFarmer] = Farmer({
            id: _idFarmer,
            idToken: idToken,
            idCollector: _idCollector,
            name: _name,
            age: _age,
            domicile: _domicile
        });

        if (bytes(_cid).length > 0) {
            string memory uri = string(abi.encodePacked(BASE_IPFS_URL, _cid));

            _safeMint(msg.sender, idToken);
            _setTokenURI(idToken, uri);
        }

        emit FarmerAdded(_idFarmer, _idCollector);
    }

    function createProject(
        string memory _cid,
        uint256 _valueProject,
        uint256 _maxInvested,
        uint256 _totalKilos,
        uint256 _profitPerKillos,
        uint256 _sharedProfit
    ) external onlyOwner returns (uint256 _idProject) {
        if (_maxInvested == 0) revert Errors.ZeroAmount();
        // Basic sanity checks to avoid nonsensical project configuration
        if (_totalKilos == 0 || _profitPerKillos == 0) {
            revert Errors.InvalidInput();
        }
        // sharedProfit is a percentage in range [0, 100]
        if (_sharedProfit > 100) {
            revert Errors.InvalidInput();
        }

        ++idToken;
        _idProject = ++idProject;

        projects[_idProject] = Project({
            id: _idProject,
            idToken: idToken,
            valueProject: _valueProject,
            maxInvested: _maxInvested,
            totalRaised: 0,
            totalKilos: _totalKilos,
            profitPerKillos: _profitPerKillos,
            sharedProfit: _sharedProfit,
            status: ProjectStatus.ACTIVE
        });

        if (bytes(_cid).length > 0) {
            string memory uri = string(abi.encodePacked(BASE_IPFS_URL, _cid));

            _safeMint(msg.sender, idToken);
            _setTokenURI(idToken, uri);
        }

        emit ProjectCreated(
            _idProject,
            msg.sender,
            _valueProject,
            _maxInvested
        );
    }

    function closeProject(uint256 _idProject) external onlyOwner {
        Project storage p = projects[_idProject];

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.CLOSED;

        emit ProjectStatusChanged(_idProject, oldStatus, ProjectStatus.CLOSED);
    }

    function refundProject(uint256 _idProject) external onlyOwner {
        Project storage p = projects[_idProject];
        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.REFUND;

        emit ProjectStatusChanged(_idProject, oldStatus, p.status);
    }

    function withdrawProject(uint256 _idProject) external onlyOwner {
        Project storage p = projects[_idProject];

        if (
            p.status == ProjectStatus.REFUND ||
            p.status == ProjectStatus.SUCCESS ||
            p.status == ProjectStatus.PROCESSED
        ) {
            revert Errors.InvalidProject();
        }

        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.SUCCESS;

        uint256 amount = p.totalRaised;
        if (amount == 0) {
            revert Errors.NothingToWithdraw();
        }

        // Reset project raised amount and transfer funds to owner.
        p.totalRaised = 0;
        IDRX.safeTransfer(msg.sender, amount);

        emit ProjectStatusChanged(_idProject, oldStatus, p.status);
    }

    function finishProject(uint256 _idProject) external nonReentrant onlyOwner {
        (, , uint256 obligationAmount) = getAdminRequiredDeposit(_idProject);
        IDRX.safeTransferFrom(msg.sender, address(this), obligationAmount);

        Project storage p = projects[_idProject];
        ProjectStatus oldStatus = p.status;
        p.status = ProjectStatus.SUCCESS;

        emit ProjectStatusChanged(_idProject, oldStatus, p.status);
    }

    function invest(
        string memory _cid,
        uint256 _idProject,
        uint256 requestedAmount
    ) external nonReentrant {
        if (_idProject == 0 || _idProject > idProject)
            revert Errors.InvalidProject();

        Project storage p = projects[_idProject];
        if (p.status != ProjectStatus.ACTIVE) revert Errors.InvalidProject();
        if (requestedAmount == 0) revert Errors.ZeroAmount();

        uint256 remaining = p.maxInvested - p.totalRaised;
        if (remaining == 0) revert Errors.MaxFundingExceeded();

        uint256 invested = requestedAmount > remaining
            ? remaining
            : requestedAmount;

        IDRX.safeTransferFrom(msg.sender, address(this), invested);

        Investment storage inv = contribution[_idProject][msg.sender];

        bool first = inv.investor == address(0);

        uint256 nftId;

        if (first) {
            nftId = ++idToken;
            uint256 invId = ++idInvestment;

            inv.id = invId;
            inv.idToken = nftId;
            inv.idProject = _idProject;
            inv.investor = msg.sender;
            inv.amount = invested;
            inv.status = InvestmentStatus.UNCLAIMED;

            if (bytes(_cid).length > 0) {
                string memory uri = string(
                    abi.encodePacked(BASE_IPFS_URL, _cid)
                );
                _safeMint(msg.sender, nftId);
                _setTokenURI(nftId, uri);
            }

            investmentsByTokenId[nftId] = inv;

            emit Invested(_idProject, msg.sender, invested, nftId);
        } else {
            if (bytes(_cid).length > 0) {
                string memory uri = string(
                    abi.encodePacked(BASE_IPFS_URL, _cid)
                );
                _setTokenURI(inv.idToken, uri);
            }

            // update only amount
            inv.amount += invested;
            emit Invested(_idProject, msg.sender, invested, inv.idToken);
        }

        p.totalRaised += invested;

        if (p.totalRaised == p.maxInvested) {
            ProjectStatus old = p.status;
            p.status = ProjectStatus.CLOSED;
            emit ProjectStatusChanged(_idProject, old, ProjectStatus.CLOSED);
        }
    }

    function claimRefund(uint256 _idProject) external nonReentrant {
        if (_idProject == 0 || _idProject > idProject) {
            revert Errors.InvalidProject();
        }

        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.REFUND) {
            revert Errors.InvalidState();
        }

        Investment storage inv = contribution[_idProject][msg.sender];

        if (inv.investor != msg.sender) {
            revert Errors.NothingToRefund();
        }

        if (inv.status != InvestmentStatus.UNCLAIMED) {
            revert Errors.NothingToRefund();
        }

        uint256 refundAmount = inv.amount;

        if (refundAmount == 0) {
            revert Errors.NothingToRefund();
        }

        inv.status = InvestmentStatus.CLAIMED;
        inv.amount = 0;

        if (p.totalRaised >= refundAmount) {
            p.totalRaised -= refundAmount;
        } else {
            p.totalRaised = 0;
        }

        IDRX.safeTransfer(msg.sender, refundAmount);

        emit Refunded(_idProject, msg.sender, refundAmount);
    }

    function claimWithdraw(uint256 _idProject) external nonReentrant {
        if (_idProject == 0 || _idProject > idProject) {
            revert Errors.InvalidProject();
        }

        Project storage p = projects[_idProject];

        if (p.status != ProjectStatus.SUCCESS) {
            revert Errors.InvalidState();
        }

        Investment storage inv = contribution[_idProject][msg.sender];

        if (inv.investor != msg.sender) {
            revert Errors.NothingToWithdraw();
        }

        if (inv.status != InvestmentStatus.UNCLAIMED) {
            revert Errors.NothingToWithdraw();
        }

        (uint256 principal, , uint256 totalReturn) = getInvestorReturn(
            _idProject,
            msg.sender
        );

        if (totalReturn == 0) {
            revert Errors.NothingToWithdraw();
        }

        inv.status = InvestmentStatus.CLAIMED;
        inv.amount = 0;

        if (p.totalRaised >= principal) {
            p.totalRaised -= principal;
        } else {
            p.totalRaised = 0;
        }

        IDRX.safeTransfer(msg.sender, totalReturn);
        emit ProfitClaimed(_idProject, msg.sender, totalReturn);
    }

    function getProjectProfitBreakdown(
        uint256 _idProject
    )
        public
        view
        returns (
            uint256 grossProfit,
            uint256 investorProfitPool,
            uint256 platformProfit
        )
    {
        Project memory p = projects[_idProject];

        grossProfit = p.totalKilos * p.profitPerKillos;

        investorProfitPool = (grossProfit * p.sharedProfit) / 100;

        platformProfit = grossProfit - investorProfitPool;
    }

    function getInvestorReturn(
        uint256 _idProject,
        address investor
    )
        public
        view
        returns (uint256 principal, uint256 profit, uint256 totalReturn)
    {
        Project memory p = projects[_idProject];

        Investment memory inv = contribution[_idProject][investor];
        principal = inv.amount;

        if (principal == 0 || p.totalRaised == 0) {
            return (principal, 0, principal);
        }

        (
            uint256 grossProfit,
            uint256 investorProfitPool,

        ) = getProjectProfitBreakdown(_idProject);

        if (grossProfit == 0 || investorProfitPool == 0) {
            return (principal, 0, principal);
        }

        profit = (investorProfitPool * principal) / p.totalRaised;

        totalReturn = principal + profit;
    }

    function getAdminRequiredDeposit(
        uint256 _idProject
    )
        public
        view
        returns (
            uint256 totalPrincipal,
            uint256 totalInvestorProfit,
            uint256 totalRequired
        )
    {
        Project memory p = projects[_idProject];

        totalPrincipal = p.totalRaised;

        (, uint256 investorProfitPool, ) = getProjectProfitBreakdown(
            _idProject
        );

        totalInvestorProfit = investorProfitPool;

        totalRequired = totalPrincipal + totalInvestorProfit;
    }
}
