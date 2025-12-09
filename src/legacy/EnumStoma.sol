// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ENUM UNTUK STATUS PROYEK
enum ProjectStatus {
    ACTIVE, // Ketika diapprove
    SUCCESS, // Ketika crowdfunding udah ditutup
    REFUNDING, // Ketika mau di refund
    CLOSED // Ketika semuanya udah selesai dan dana investor balik
}
