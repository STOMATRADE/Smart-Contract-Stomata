// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ProjectStorage} from "./utils/ProjectStorage.sol";
import {FarmerStorage} from "./utils/FarmerStorage.sol";
import {Event} from "./utils/Event.sol";
import {Constant} from "./utils/Constant.sol";

import "./utils/Errors.sol";
import "./utils/Enum.sol";

contract Stomatrade is
    ERC721URIStorage,
    ReentrancyGuard,
    Ownable,
    ProjectStorage,
    FarmerStorage,
    Event,
    Constant
{
    using SafeERC20 for IERC20;
    IERC20 public immutable idrx;

    constructor(
        address idrxTokenAddress
    ) ERC721("Stomatrade", "STMX") Ownable(msg.sender) {
        if (idrxTokenAddress == address(0)) revert Errors.ZeroAddress();
        idrx = IERC20(idrxTokenAddress);
    }

    function addFarmer(
        string memory _cid,
        string memory _idCollector,
        string memory _name,
        uint256 _age,
        string memory _domicile
    ) external onlyOwner returns (uint256 _idFarmer) {
        _idFarmer = idFarmer++;
        farmers[_idFarmer] = Farmer({
            id: _idFarmer,
            idCollector: _idCollector,
            name: _name,
            age: _age,
            domicile: _domicile
        });

        if (bytes(_cid).length > 0) {
            string memory uri = string(abi.encodePacked(BASE_IPFS_URL, _cid));

            _safeMint(msg.sender, _idFarmer);
            _setTokenURI(_idFarmer, uri);
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
        if (msg.sender == address(0)) revert Errors.ZeroAddress();

        _idProject = idProject++;
        projects[_idProject] = Project({
            id: _idProject,
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

            _safeMint(msg.sender, _idProject);
            _setTokenURI(_idProject, uri);
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
        p.status = ProjectStatus.CLOSED;
        emit ProjectStatusChanged(
            _idProject,
            ProjectStatus.ACTIVE,
            ProjectStatus.CLOSED
        );
    }

    function refundProject(uint256 _idProject) external onlyOwner {
        Project storage p = projects[_idProject];
        p.status = ProjectStatus.REFUND;
        emit ProjectStatusChanged(
            _idProject,
            ProjectStatus.ACTIVE,
            ProjectStatus.CLOSED
        );
    }

    function finishProject(uint256 _idProject) external nonReentrant onlyOwner {
        (, , uint256 obligationAmount) = getAdminRequiredDeposit(_idProject);
        idrx.safeTransferFrom(msg.sender, address(this), obligationAmount);

        Project storage p = projects[_idProject];
        p.status = ProjectStatus.SUCCESS;
        emit ProjectStatusChanged(
            _idProject,
            ProjectStatus.ACTIVE,
            ProjectStatus.CLOSED
        );
    }

    function invest(
        string memory _cid,
        uint256 projectId,
        uint256 requestedAmount
    ) external nonReentrant {
        if (projectId == 0 || projectId >= idProject) {
            revert Errors.InvalidProject();
        }
        if (requestedAmount == 0) revert Errors.ZeroAmount();

        Project storage p = projects[projectId];

        if (p.status != ProjectStatus.ACTIVE) {
            revert Errors.InvalidProject();
        }

        uint256 freeToInvest = p.maxInvested - p.totalRaised;
        if (freeToInvest == 0) {
            revert Errors.MaxFundingExceeded();
        }

        uint256 invested = requestedAmount;
        if (requestedAmount > freeToInvest) {
            invested = freeToInvest;
        }

        idrx.safeTransferFrom(msg.sender, address(this), invested);
        Investment storage userInvest = contribution[projectId][msg.sender];

        bool isExistingInvestor = (userInvest.investor == msg.sender);
        uint256 investmentId;

        if (!isExistingInvestor) {
            investmentId = idInvestment++;

            userInvest.id = investmentId;
            userInvest.idProject = projectId;
            userInvest.investor = msg.sender;
            userInvest.amount = invested;
            userInvest.status = InvestmentStatus.UNCLAIMED;

            if (bytes(_cid).length > 0) {
                string memory uri = string(
                    abi.encodePacked(BASE_IPFS_URL, _cid)
                );
                _safeMint(msg.sender, investmentId);
                _setTokenURI(investmentId, uri);
            }
        } else {
            investmentId = userInvest.id;
            userInvest.amount += invested;

            if (bytes(_cid).length > 0) {
                string memory uri = string(
                    abi.encodePacked(BASE_IPFS_URL, _cid)
                );
                _setTokenURI(investmentId, uri);
            }
        }

        investmentsByTokenId[investmentId] = userInvest;
        p.totalRaised += invested;

        emit Invested(projectId, msg.sender, invested, investmentId);

        if (p.totalRaised == p.maxInvested) {
            ProjectStatus oldStatus = p.status;
            p.status = ProjectStatus.CLOSED;
            emit ProjectStatusChanged(
                projectId,
                oldStatus,
                ProjectStatus.CLOSED
            );
        }
    }

    function claimRefund(uint256 projectId) external nonReentrant {
        if (projectId == 0 || projectId >= idProject) {
            revert Errors.InvalidProject();
        }

        Project storage p = projects[projectId];

        if (p.status != ProjectStatus.REFUND) {
            revert Errors.InvalidState();
        }

        Investment storage inv = contribution[projectId][msg.sender];

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

        idrx.safeTransfer(msg.sender, refundAmount);

        emit Refunded(projectId, msg.sender, refundAmount);
    }

    function claimWithdraw(uint256 projectId) external nonReentrant {
        if (projectId == 0 || projectId >= idProject) {
            revert Errors.InvalidProject();
        }

        Project storage p = projects[projectId];

        if (p.status != ProjectStatus.SUCCESS) {
            revert Errors.InvalidState();
        }

        Investment storage inv = contribution[projectId][msg.sender];

        if (inv.investor != msg.sender) {
            revert Errors.NothingToWithdraw();
        }

        if (inv.status != InvestmentStatus.UNCLAIMED) {
            revert Errors.NothingToWithdraw();
        }

        (uint256 principal, , uint256 totalReturn) = getInvestorReturn(
            projectId,
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

        idrx.safeTransfer(msg.sender, totalReturn);
        emit ProfitClaimed(projectId, msg.sender, totalReturn);
    }

    function getProjectProfitBreakdown(
        uint256 projectId
    )
        public
        view
        returns (
            uint256 grossProfit,
            uint256 investorProfitPool,
            uint256 platformProfit
        )
    {
        Project memory p = projects[projectId];

        grossProfit = p.totalKilos * p.profitPerKillos;

        investorProfitPool = (grossProfit * p.sharedProfit) / 100;

        platformProfit = grossProfit - investorProfitPool;
    }

    function getInvestorReturn(
        uint256 projectId,
        address investor
    )
        public
        view
        returns (uint256 principal, uint256 profit, uint256 totalReturn)
    {
        Project memory p = projects[projectId];

        Investment memory inv = contribution[projectId][investor];
        principal = inv.amount;

        if (principal == 0 || p.totalRaised == 0) {
            return (principal, 0, principal);
        }

        (
            uint256 grossProfit,
            uint256 investorProfitPool,

        ) = getProjectProfitBreakdown(projectId);

        if (grossProfit == 0 || investorProfitPool == 0) {
            return (principal, 0, principal);
        }

        profit = (investorProfitPool * principal) / p.totalRaised;

        totalReturn = principal + profit;
    }

    function getAdminRequiredDeposit(
        uint256 projectId
    )
        public
        view
        returns (
            uint256 totalPrincipal,
            uint256 totalInvestorProfit,
            uint256 totalRequired
        )
    {
        Project memory p = projects[projectId];

        totalPrincipal = p.totalRaised;

        (, uint256 investorProfitPool, ) = getProjectProfitBreakdown(projectId);

        totalInvestorProfit = investorProfitPool;

        totalRequired = totalPrincipal + totalInvestorProfit;
    }
}
