// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "./Enum.sol";

contract Event {
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

    event FarmerAdded(uint256 indexed idFarmer, string indexed idCollector);

    event ProfitClaimed(
        uint256 indexed idProject,
        address indexed user,
        uint256 amount
    );
}
