// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library Errors {
    error Unauthorized();
    error ApprovalNotAllowed();
    error TransferNotAllowed();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error MaxFundingExceeded();
    error InvalidProject();
    error InvalidState();
    error NothingToRefund();
    error NothingToWithdraw();
}
