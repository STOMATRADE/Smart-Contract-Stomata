// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/MockIDRX.sol";
import "../src/MainStoma.sol" ;

contract StomaTradeTest is Test {
    StomaTrade public stomatrade;
    MockIDRX public idrx;

    address owner = address(1);
    address investor = address(2);
    address investor2 = address(3);

function setUp() public {
    owner = address(1);
    investor = address(2);
    investor2 = address(3);

    // =========================
    // DEPLOY SEBAGAI OWNER
    // =========================
    vm.startPrank(owner);

    idrx = new MockIDRX(1000000000000);
    stomatrade = new StomaTrade(address(idrx));

    vm.stopPrank();

    // =========================
    // MINT HARUS DARI OWNER TOKEN
    // =========================
    vm.prank(owner);
    idrx.mint(investor, 1000 ether);

    vm.prank(owner);
    idrx.mint(investor2, 1000 ether);

    // =========================
    // APPROVAL DARI INVESTOR
    // =========================
    vm.prank(investor);
    idrx.approve(address(stomatrade), type(uint256).max);

    vm.prank(investor2);
    idrx.approve(address(stomatrade), type(uint256).max);
}


    // =========================
    // ✅ CREATE PROJECT
    // =========================
    function testCreateProject() public {
        vm.prank(owner);

        uint256 id = stomatrade.createProject(
            100 ether,
            500 ether,
            "QmTestCID"
        );

        (
            uint256 pid,
            address projectOwner,
            ,
            uint256 totalRaised,
            ProjectStatus status
        ) = stomatrade.getProject(id);

        assertEq(pid, 1);
        assertEq(projectOwner, owner);
        assertEq(totalRaised, 0);
        assertEq(uint256(status), uint256(ProjectStatus.ACTIVE));
    }

    // =========================
    // ✅ INVEST TEST
    // =========================
    function testInvest() public {
        vm.prank(owner);
        uint256 pid = stomatrade.createProject(
            100 ether,
            500 ether,
            "QmTestCID"
        );

        vm.prank(investor);
        stomatrade.invest(pid, 200 ether);

        (, , , uint256 raised, ) = stomatrade.getProject(pid);
        assertEq(raised, 200 ether);
    }

    // =========================
    // ✅ MULTI INVEST + AUTO SUCCESS
    // =========================
    function testAutoSuccessWhenFull() public {
        vm.prank(owner);
        uint256 pid = stomatrade.createProject(
            100 ether,
            300 ether,
            "QmTestCID"
        );

        vm.prank(investor);
        stomatrade.invest(pid, 200 ether);

        vm.prank(investor2);
        stomatrade.invest(pid, 100 ether);

        (, , , uint256 raised, ProjectStatus status) = stomatrade.getProject(pid);

        assertEq(raised, 300 ether);
        assertEq(uint256(status), uint256(ProjectStatus.SUCCESS));
    }

    // =========================
    // ✅ PROFIT CLAIM TEST
    // =========================
    function testProfitClaim() public {
        vm.prank(owner);
        uint256 pid = stomatrade.createProject(
            100 ether,
            500 ether,
            "QmTestCID"
        );

        vm.prank(investor);
        stomatrade.invest(pid, 200 ether);

        vm.prank(owner);
        idrx.approve(address(stomatrade), 100 ether);
        vm.prank(owner);
        stomatrade.depositProfit(pid, 100 ether);

        uint256 before = idrx.balanceOf(investor);

        vm.prank(investor);
        stomatrade.claimProfit(pid);

        uint256 afterBal = idrx.balanceOf(investor);
        assertGt(afterBal, before);
    }

    function testRefund() public {
        vm.prank(owner);
        uint256 pid = stomatrade.createProject(
            100 ether,
            500 ether,
            "QmTestCID"
        );

        vm.prank(investor);
        stomatrade.invest(pid, 200 ether);

        vm.prank(owner);
        stomatrade.refundable(pid);

        uint256 before = idrx.balanceOf(investor);

        vm.prank(investor);
        stomatrade.claimRefund(pid);

        uint256 afterBal = idrx.balanceOf(investor);
        assertEq(afterBal, before + 200 ether);
    }
}
