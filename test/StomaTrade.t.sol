// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/MainStoma.sol";
import "../src/MockIDRX.sol"; // mock token IDRX

contract StomaTradeTest is Test {
    StomaTrade public stoma;
    MockIDRX public idrx;

    address public owner = address(0xABCD);
    address public investor1 = address(0x1111);
    address public investor2 = address(0x2222);

    function setUp() public {
        // Deploy mock token
        vm.prank(owner);
        idrx = new MockIDRX(1_000_000 ether);

        // Deploy StomaTrade contract
        vm.prank(owner);
        stoma = new StomaTrade(address(idrx));

        // Transfer token ke investor
        idrx.transfer(investor1, 1_000 ether);
        idrx.transfer(investor2, 1_000 ether);
    }

    // ================================
    // TEST CREATE PROJECT
    // ================================
    function testCreateProject() public {
        vm.prank(owner);
        uint256 projectId = stoma.createProject(
            1000 ether,
            1000 ether,
            "QmTestCid",
            owner,
            100,
            10,
            1
        );

        (,,uint256 value,,ProjectStatus status,,,) = stoma.getProject(projectId);
        assertEq(value, 1000 ether);
        assertEq(uint(status), uint(ProjectStatus.ACTIVE));
    }

    // ================================
    // TEST INVEST & CLAIM PROFIT
    // ================================
    function testInvestAndClaimProfit() public {
        vm.prank(owner);
        uint256 projectId = stoma.createProject(
            1000 ether,
            1000 ether,
            "QmTestCid",
            owner,
            100,
            10,
            1
        );

        // Investor1 invest 200
        vm.startPrank(investor1);
        idrx.approve(address(stoma), 200 ether);
        stoma.invest(projectId, 200 ether);
        vm.stopPrank();

        // Investor2 invest 300
        vm.startPrank(investor2);
        idrx.approve(address(stoma), 300 ether);
        stoma.invest(projectId, 300 ether);
        vm.stopPrank();

        // Owner deposit profit 100
        vm.prank(owner);
        idrx.approve(address(stoma), 100 ether);
        stoma.depositProfit(projectId, 100 ether);

        // Investor1 claim profit
        vm.startPrank(investor1);
        stoma.claimProfit(projectId);
        vm.stopPrank();

        // Investor2 claim profit
        vm.startPrank(investor2);
        stoma.claimProfit(projectId);
        vm.stopPrank();

        // Check balances
        uint256 investor1Balance = idrx.balanceOf(investor1);
        uint256 investor2Balance = idrx.balanceOf(investor2);

        assertTrue(investor1Balance > 200 ether);
        assertTrue(investor2Balance > 300 ether);
    }

    // ================================
    // TEST REFUND
    // ================================
    function testRefund() public {
        vm.prank(owner);
        uint256 projectId = stoma.createProject(
            1000 ether,
            1000 ether,
            "QmTestCid",
            owner,
            100,
            10,
            1
        );

        // Investor1 invest 200
        vm.startPrank(investor1);
        idrx.approve(address(stoma), 200 ether);
        stoma.invest(projectId, 200 ether);
        vm.stopPrank();

        // Owner set project to refundable
        vm.prank(owner);
        stoma.refundable(projectId);

        // Investor1 claim refund
        vm.startPrank(investor1);
        stoma.claimRefund(projectId, investor1);
        vm.stopPrank();

        uint256 refundedBalance = idrx.balanceOf(investor1);
        assertEq(refundedBalance, 1000 ether);
    }

    // ================================
    // TEST FARMER NFT MINT
    // ================================
    function testFarmerNFTMint() public {
        vm.startPrank(investor1);
        stoma.nftFarmer("Padi");
        vm.stopPrank();

        string memory name = stoma.farmerName(1);
        assertEq(name, "Padi");
    }

    // ================================
    // TEST SET PROJECT STATUS
    // ================================
    function testSetProjectStatus() public {
        vm.prank(owner);
        uint256 projectId = stoma.createProject(
            1000 ether,
            1000 ether,
            "QmTestCid",
            owner,
            100,
            10,
            1
        );

        vm.prank(owner);
        stoma.setProjectStatus(projectId, ProjectStatus.CLOSED);

        (, , , , ProjectStatus status, , ,) = stoma.getProject(projectId);
        assertEq(uint(status), uint(ProjectStatus.CLOSED));
    }

    // ================================
    // TEST GET CLAIMABLE PROFIT
    // ================================
    function testGetClaimableProfit() public {
        vm.prank(owner);
        uint256 projectId = stoma.createProject(
            1000 ether,
            1000 ether,
            "QmTestCid",
            owner,
            100,
            10,
            1
        );

        // Investor1 invest 200
        vm.startPrank(investor1);
        idrx.approve(address(stoma), 200 ether);
        stoma.invest(projectId, 200 ether);
        vm.stopPrank();

        // Owner deposit profit 100
        vm.prank(owner);
        idrx.approve(address(stoma), 100 ether);
        stoma.depositProfit(projectId, 100 ether);

        uint256 claimable = stoma.getClaimableProfit(projectId, investor1);
        assertTrue(claimable > 0);
    }
}
