// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StomaTrade.sol";
import "../src/MockIDRX.sol";

contract StomaTradeTest is Test {
    StomaTrade public stoma;
    MockIDRX public idrx;

    address public owner;
    address public projectOwner;
    address public investor1;
    address public investor2;
    address public investor3;

    uint256 constant INITIAL_SUPPLY = 10_000_000; // 10 juta IDRX sudah pakai decimals
    uint256 constant PROJECT_VALUE = 100_000;
    uint256 constant MAX_FUNDING = 50_000;

    event ProjectCreated(uint256 indexed idProject, address indexed owner, uint256 valueProject, uint256 maxCrowdFunding);
    event Invested(uint256 indexed idProject, address indexed investor, uint256 amount, uint256 receiptTokenId);
    event ProfitDeposited(uint256 indexed idProject, uint256 amount);
    event ProfitClaimed(uint256 indexed idProject, address indexed user, uint256 amount);

    function setUp() public {
        owner = address(this);
        projectOwner = makeAddr("projectOwner");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        investor3 = makeAddr("investor3");

        idrx = new MockIDRX(INITIAL_SUPPLY);
        stoma = new StomaTrade(address(idrx));

        // Distribusi token ke investor (unit token biasa)
        idrx.mint(investor1, 100_000);
        idrx.mint(investor2, 100_000);
        idrx.mint(investor3, 100_000);

        console.log("=== SETUP COMPLETE ===");
        console.log("IDRX deployed at:", address(idrx));
        console.log("StomaTrade deployed at:", address(stoma));
        console.log("Owner balance:", idrx.balanceOfIDRX(owner));
    }

    // ================= HELPER FUNCTION =================
    function createAndApproveProject() internal returns (uint256 projectId) {
        projectId = stoma.createProject(projectOwner, PROJECT_VALUE, MAX_FUNDING);
        stoma.approveProject(projectId);
    }

    // ================= TEST CREATE PROJECT =================
    function testCreateProject() public {
        uint256 projectId = stoma.createProject(projectOwner, PROJECT_VALUE, MAX_FUNDING);

        (uint256 id, address owner_, uint256 maxFunding, uint256 raised, StomaTrade.ProjectStatus status) = stoma.getProject(projectId);
        assertEq(id, projectId);
        assertEq(owner_, projectOwner);
        assertEq(maxFunding, MAX_FUNDING);
        assertEq(raised, 0);
        assertEq(uint8(status), uint8(StomaTrade.ProjectStatus.PENDING));

        console.log("Project created successfully!");
    }

    function testCreateProjectWithZeroFunding() public {
        vm.expectRevert(StomaTrade.ZeroAmount.selector);
        stoma.createProject(projectOwner, PROJECT_VALUE, 0);
    }

    function testCreateProjectOnlyOwner() public {
        vm.prank(investor1);
        vm.expectRevert();
        stoma.createProject(projectOwner, PROJECT_VALUE, MAX_FUNDING);
    }

    // ================= TEST INVEST =================
    function testInvest() public {
        uint256 projectId = createAndApproveProject();

        uint256 investAmount = 10_000;

        vm.startPrank(investor1);
        idrx.approve(address(stoma), investAmount);
        vm.expectEmit(true, true, false, true);
        emit Invested(projectId, investor1, investAmount, 1);
        stoma.invest(projectId, investAmount);
        vm.stopPrank();

        assertEq(stoma.contribution(projectId, investor1), investAmount);
        assertEq(stoma.ownerOf(1), investor1);

        (, , , uint256 raised, ) = stoma.getProject(projectId);
        assertEq(raised, investAmount);

        console.log("Investment successful!");
    }

    function testInvestMultipleInvestors() public {
        uint256 projectId = createAndApproveProject();

        uint256 amount1 = 20_000;
        uint256 amount2 = 15_000;
        uint256 amount3 = 15_000;

        vm.startPrank(investor1);
        idrx.approve(address(stoma), amount1);
        stoma.invest(projectId, amount1);
        vm.stopPrank();

        vm.startPrank(investor2);
        idrx.approve(address(stoma), amount2);
        stoma.invest(projectId, amount2);
        vm.stopPrank();

        vm.startPrank(investor3);
        idrx.approve(address(stoma), amount3);
        stoma.invest(projectId, amount3);
        vm.stopPrank();

        (, , , uint256 raised, StomaTrade.ProjectStatus status) = stoma.getProject(projectId);
        assertEq(raised, MAX_FUNDING);
        assertEq(uint8(status), uint8(StomaTrade.ProjectStatus.SUCCESS));

        console.log("Multiple investors invested successfully!");
    }

    function testInvestExceedMaxFunding() public {
        uint256 projectId = createAndApproveProject();

        uint256 exceedAmount = MAX_FUNDING + 1;

        vm.startPrank(investor1);
        idrx.approve(address(stoma), exceedAmount);
        vm.expectRevert(StomaTrade.MaxFundingExceeded.selector);
        stoma.invest(projectId, exceedAmount);
        vm.stopPrank();
    }

    function testInvestWithZeroAmount() public {
        uint256 projectId = createAndApproveProject();

        vm.prank(investor1);
        vm.expectRevert(StomaTrade.ZeroAmount.selector);
        stoma.invest(projectId, 0);
    }

    // ================= TEST WITHDRAW =================
    function testWithdrawProjectFund() public {
        uint256 projectId = createAndApproveProject();

        vm.startPrank(investor1);
        idrx.approve(address(stoma), MAX_FUNDING);
        stoma.invest(projectId, MAX_FUNDING);
        vm.stopPrank();

        uint256 balanceBefore = idrx.balanceOfIDRX(projectOwner);
        stoma.withDrawProjectFund(projectId);
        uint256 balanceAfter = idrx.balanceOfIDRX(projectOwner);

        assertEq(balanceAfter - balanceBefore, MAX_FUNDING);

        (, , , , StomaTrade.ProjectStatus status) = stoma.getProject(projectId);
        assertEq(uint8(status), uint8(StomaTrade.ProjectStatus.CLOSED));

        console.log("Project fund withdrawn!");
    }

    // ================= TEST REFUND =================
    function testRefund() public {
        uint256 projectId = createAndApproveProject();

        uint256 investAmount = 10_000;
        vm.startPrank(investor1);
        idrx.approve(address(stoma), investAmount);
        stoma.invest(projectId, investAmount);
        vm.stopPrank();

        stoma.refundable(projectId);

        uint256 balanceBefore = idrx.balanceOfIDRX(investor1);
        vm.prank(investor1);
        stoma.claimRefund(projectId);
        uint256 balanceAfter = idrx.balanceOfIDRX(investor1);

        assertEq(balanceAfter - balanceBefore, investAmount);
        assertEq(stoma.contribution(projectId, investor1), 0);

        console.log("Refund claimed successfully!");
    }

    // ================= TEST PROFIT DISTRIBUTION =================
    function testProfitDistribution() public {
        uint256 projectId = createAndApproveProject();

        vm.startPrank(investor1);
        idrx.approve(address(stoma), 20_000);
        stoma.invest(projectId, 20_000);
        vm.stopPrank();

        vm.startPrank(investor2);
        idrx.approve(address(stoma), 30_000);
        stoma.invest(projectId, 30_000);
        vm.stopPrank();

        stoma.withDrawProjectFund(projectId);

        uint256 profit = 10_000;
        idrx.approve(address(stoma), profit);
        vm.expectEmit(true, false, false, true);
        emit ProfitDeposited(projectId, profit);
        stoma.depositProfit(projectId, profit);

        uint256 claimable1 = stoma.getClaimableProfit(projectId, investor1);
        uint256 claimable2 = stoma.getClaimableProfit(projectId, investor2);

        assertEq(claimable1, 4_000);
        assertEq(claimable2, 6_000);

        vm.prank(investor1);
        stoma.claimProfit(projectId);

        uint256 balance1After = idrx.balanceOfIDRX(investor1);
        assertEq(balance1After, 4_000);

        console.log("Profit distributed correctly!");
    }

    // ================= TEST NFT SBT =================
    function testNFTTransferDisabled() public {
        uint256 projectId = createAndApproveProject();

        vm.startPrank(investor1);
        idrx.approve(address(stoma), 10_000);
        stoma.invest(projectId, 10_000);
        vm.expectRevert(StomaTrade.TransferNotAllowed.selector);
        stoma.transferFrom(investor1, investor2, 1);
        vm.stopPrank();
    }

    function testNFTApprovalDisabled() public {
        uint256 projectId = createAndApproveProject();

        vm.startPrank(investor1);
        idrx.approve(address(stoma), 10_000);
        stoma.invest(projectId, 10_000);
        vm.expectRevert(StomaTrade.ApprovalNotAllowed.selector);
        stoma.approve(investor2, 1);
        vm.stopPrank();
    }

    // ================= TEST EDGE CASES =================
    function testGetInvalidProject() public {
        vm.expectRevert(StomaTrade.InvalidProject.selector);
        stoma.getProject(999);
    }

    function testInvestToClosedProject() public {
        uint256 projectId = createAndApproveProject();

        vm.startPrank(investor1);
        idrx.approve(address(stoma), MAX_FUNDING);
        stoma.invest(projectId, MAX_FUNDING);
        vm.stopPrank();

        stoma.withDrawProjectFund(projectId);

        vm.startPrank(investor2);
        idrx.approve(address(stoma), 1_000);
        vm.expectRevert(StomaTrade.InvalidStatus.selector);
        stoma.invest(projectId, 1_000);
        vm.stopPrank();
    }
}
