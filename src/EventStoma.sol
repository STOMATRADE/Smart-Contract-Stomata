// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "./EnumStoma.sol" ;

contract Event  {

    event ProjectCreated(
        uint256 indexed idProject,  // id project
        address indexed owner,      // address collector
        uint256 valueProject,       // total nilai project
        uint256 maxCrowdFunding,    // dana yang dibutuhkan
        uint256 profitShare ,       // on percentage
        uint256 fee                 // per kg
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

    event FarmerMinted(
        address indexed farmer,
        uint256 indexed nftId,
        string namaKomoditas
    );

    event ProfitClaimed(
        uint256 indexed idProject,
        address indexed user,
        uint256 amount
    );
}
