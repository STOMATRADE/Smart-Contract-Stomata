// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./EnumStoma.sol";

struct Project {
    uint256 id;
    address projectOwner;
    uint256 valueProject;
    uint256 maxCrowdFunding;
    uint256 totalRaised;
    ProjectStatus status;
    uint256 profitShare ;
    uint256 fee ;
    uint256 totalKG ;
}

struct Investment {
    uint256 idProject;
    address investor;
    uint256 amount;
}
