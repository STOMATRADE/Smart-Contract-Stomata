// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract FarmerStorage {
    struct Farmer {
        uint256 id;
        uint256 idToken;
        string idCollector;
        string name;
        uint256 age;
        string domicile;
    }

    mapping(uint256 => Farmer) public farmers;
    uint256 public idFarmer = 1;
}
