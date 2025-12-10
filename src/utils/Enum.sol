// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

enum ProjectStatus {
    ACTIVE, // when created and approved by admin
    CLOSED, // whne project closed to be invested by public
    PROCESSED, // the invested liquidity has been withdraweb by stomata and being processed
    REFUND, // when the project is failed and liquidity is refunded
    SUCCESS // when the project has finished and success and investor could clain the rewards
}

enum InvestmentStatus {
    CLAIMED, // when investmend has been claimed by investor
    UNCLAIMED // when investmend has not been claimed by investor
}