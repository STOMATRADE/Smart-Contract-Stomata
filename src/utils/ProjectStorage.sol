// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ProjectStatus, InvestmentStatus} from "./Enum.sol";

contract ProjectStorage {
    uint256 public idProject = 1;
    uint256 public idInvestment = 1;

    struct Project {
        uint256 id;
        uint256 idToken;
        uint256 valueProject; // total liquidity needs project
        uint256 maxInvested; // total liquidity available for public
        uint256 totalRaised; // total liquidity raised
        uint256 totalKilos; // total killos of project deals
        uint256 profitPerKillos; // profit per kilos of project deals
        uint256 sharedProfit; // percentage profit sharing for the investor
        ProjectStatus status;
    }

    struct Investment {
        uint256 id;
        uint256 idToken;
        uint256 idProject;
        address investor;
        uint256 amount;
        InvestmentStatus status;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Investment)) public contribution;
    mapping(uint256 => Investment) public investmentsByTokenId;
}
