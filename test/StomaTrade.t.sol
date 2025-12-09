// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Stomatrade.sol";
import "../src/MockIDRX.sol";

contract StomatradeTest is Test {
    Stomatrade public stomatrade;
    MockIDRX public idrx;

    address owner = address(1);
    address investor1 = address(2);
    address investor2 = address(3);
    address investor3 = address(4);
    address nonInvestor = address(5);
    address zeroAddress = address(0);

    uint256 constant INITIAL_SUPPLY = 1000000000000;
    string constant TEST_CID = "QmTestCID";
    string constant TEST_COLLECTOR_ID = "collector123";
    string constant TEST_FARMER_NAME = "John Doe";
    uint256 constant TEST_AGE = 30;
    string constant TEST_DOMICILE = "Jakarta";
    uint256 constant TEST_PROJECT_VALUE = 1000 ether;
    uint256 constant TEST_MAX_INVESTED = 5000 ether;
    uint256 constant TEST_TOTAL_KILOS = 1000;
    uint256 constant TEST_PROFIT_PER_KILOS = 1000000000000000000; // 1 token per kilo
    uint256 constant TEST_SHARED_PROFIT = 80; // 80% shared with investors

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock token
        idrx = new MockIDRX(INITIAL_SUPPLY);

        // Deploy stomatrade contract
        stomatrade = new Stomatrade(address(idrx));

        vm.stopPrank();

        // Mint tokens to investors
        vm.prank(address(idrx).owner());
        idrx.mint(investor1, 10000 ether);
        vm.prank(address(idrx).owner());
        idrx.mint(investor2, 10000 ether);
        vm.prank(address(idrx).owner());
        idrx.mint(investor3, 10000 ether);

        // Approve stomatrade contract to spend tokens
        vm.prank(investor1);
        idrx.approve(address(stomatrade), type(uint256).max);
        vm.prank(investor2);
        idrx.approve(address(stomatrade), type(uint256).max);
        vm.prank(investor3);
        idrx.approve(address(stomatrade), type(uint256).max);
    }

    // Test constructor with valid address
    function testConstructorWithValidAddress() public {
        Stomatrade newStomatrade = new Stomatrade(address(idrx));
        assertEq(address(newStomatrade.idrx()), address(idrx));
        assertEq(newStomatrade.name(), "Stomatrade");
        assertEq(newStomatrade.symbol(), "STMX");
    }

    // Test constructor reverts with zero address
    function testConstructorFailsWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        new Stomatrade(zeroAddress);
    }

    // Test addFarmer function
    function testAddFarmer() public {
        vm.prank(owner);
        uint256 farmerId = stomatrade.addFarmer(
            TEST_CID,
            TEST_COLLECTOR_ID,
            TEST_FARMER_NAME,
            TEST_AGE,
            TEST_DOMICILE
        );

        Farmer memory farmer = stomatrade.farmers(farmerId);
        assertEq(farmer.id, 1);
        assertEq(farmer.idCollector, TEST_COLLECTOR_ID);
        assertEq(farmer.name, TEST_FARMER_NAME);
        assertEq(farmer.age, TEST_AGE);
        assertEq(farmer.domicile, TEST_DOMICILE);
        
        // Check if NFT was minted
        assertEq(stomatrade.ownerOf(farmerId), owner);
        assertEq(stomatrade.tokenURI(farmerId), "https://gateway.pinata.cloud/ipfs/QmTestCID");
    }

    // Test addFarmer without CID (no NFT minting)
    function testAddFarmerWithoutCID() public {
        vm.prank(owner);
        uint256 farmerId = stomatrade.addFarmer(
            "",
            TEST_COLLECTOR_ID,
            TEST_FARMER_NAME,
            TEST_AGE,
            TEST_DOMICILE
        );

        Farmer memory farmer = stomatrade.farmers(farmerId);
        assertEq(farmer.id, 1);
        assertEq(farmer.idCollector, TEST_COLLECTOR_ID);
        assertEq(farmer.name, TEST_FARMER_NAME);
        assertEq(farmer.age, TEST_AGE);
        assertEq(farmer.domicile, TEST_DOMICILE);
    }

    // Test addFarmer reverts when called by non-owner
    function testAddFarmerRevertsWhenCalledByNonOwner() public {
        vm.prank(investor1);
        vm.expectRevert("Ownable: caller is not the owner");
        stomatrade.addFarmer(
            TEST_CID,
            TEST_COLLECTOR_ID,
            TEST_FARMER_NAME,
            TEST_AGE,
            TEST_DOMICILE
        );
    }

    // Test createProject function
    function testCreateProject() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.id, 1);
        assertEq(project.valueProject, TEST_PROJECT_VALUE);
        assertEq(project.maxInvested, TEST_MAX_INVESTED);
        assertEq(project.totalRaised, 0);
        assertEq(project.totalKilos, TEST_TOTAL_KILOS);
        assertEq(project.profitPerKillos, TEST_PROFIT_PER_KILOS);
        assertEq(project.sharedProfit, TEST_SHARED_PROFIT);
        assertEq(uint8(project.status), uint8(ProjectStatus.ACTIVE));
        
        // Check if NFT was minted
        assertEq(stomatrade.ownerOf(projectId), owner);
        assertEq(stomatrade.tokenURI(projectId), "https://gateway.pinata.cloud/ipfs/QmTestCID");
    }

    // Test createProject without CID (no NFT minting)
    function testCreateProjectWithoutCID() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            "",
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.id, 1);
        assertEq(project.valueProject, TEST_PROJECT_VALUE);
        assertEq(project.maxInvested, TEST_MAX_INVESTED);
        assertEq(project.totalRaised, 0);
        assertEq(project.totalKilos, TEST_TOTAL_KILOS);
        assertEq(project.profitPerKillos, TEST_PROFIT_PER_KILOS);
        assertEq(project.sharedProfit, TEST_SHARED_PROFIT);
        assertEq(uint8(project.status), uint8(ProjectStatus.ACTIVE));
    }

    // Test createProject reverts when maxInvested is 0
    function testCreateProjectRevertsWhenMaxInvestedIsZero() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector));
        stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            0,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );
    }

    // Test createProject reverts when called by non-owner
    function testCreateProjectRevertsWhenCalledByNonOwner() public {
        vm.prank(investor1);
        vm.expectRevert("Ownable: caller is not the owner");
        stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );
    }

    // Test closeProject function
    function testCloseProject() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(owner);
        stomatrade.closeProject(projectId);

        Project memory project = stomatrade.projects(projectId);
        assertEq(uint8(project.status), uint8(ProjectStatus.CLOSED));
    }

    // Test closeProject reverts when called by non-owner
    function testCloseProjectRevertsWhenCalledByNonOwner() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        vm.expectRevert("Ownable: caller is not the owner");
        stomatrade.closeProject(projectId);
    }

    // Test refundProject function
    function testRefundProject() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(owner);
        stomatrade.refundProject(projectId);

        Project memory project = stomatrade.projects(projectId);
        assertEq(uint8(project.status), uint8(ProjectStatus.REFUND));
    }

    // Test refundProject reverts when called by non-owner
    function testRefundProjectRevertsWhenCalledByNonOwner() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        vm.expectRevert("Ownable: caller is not the owner");
        stomatrade.refundProject(projectId);
    }

    // Test finishProject function
    function testFinishProject() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        // Invest to have funds to return to investors
        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Calculate required deposit
        (uint256 totalPrincipal, uint256 totalInvestorProfit, uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(projectId);

        // Approve token transfer for the required amount
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        vm.prank(owner);
        stomatrade.finishProject(projectId);

        Project memory project = stomatrade.projects(projectId);
        assertEq(uint8(project.status), uint8(ProjectStatus.SUCCESS));
    }

    // Test finishProject reverts when called by non-owner
    function testFinishProjectRevertsWhenCalledByNonOwner() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        vm.expectRevert("Ownable: caller is not the owner");
        stomatrade.finishProject(projectId);
    }

    // Test invest function
    function testInvest() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 1000 ether);

        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(investment.id, 1);
        assertEq(investment.investor, investor1);
        assertEq(investment.amount, 1000 ether);
        assertEq(uint8(investment.status), uint8(InvestmentStatus.UNCLAIMED));
        
        // Check if investment NFT was minted
        assertEq(stomatrade.ownerOf(1), investor1);
        assertEq(stomatrade.tokenURI(1), "https://gateway.pinata.cloud/ipfs/QmTestCID");
    }

    // Test invest without CID (no investment NFT minting)
    function testInvestWithoutCID() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            "",
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest("", projectId, 1000 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 1000 ether);

        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(investment.id, 1);
        assertEq(investment.investor, investor1);
        assertEq(investment.amount, 1000 ether);
        assertEq(uint8(investment.status), uint8(InvestmentStatus.UNCLAIMED));
    }

    // Test invest with zero amount reverts
    function testInvestWithZeroAmountReverts() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector));
        stomatrade.invest(TEST_CID, projectId, 0);
    }

    // Test invest with invalid project ID reverts
    function testInvestWithInvalidProjectIdReverts() public {
        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidProject.selector));
        stomatrade.invest(TEST_CID, 999, 1000 ether);
    }

    // Test invest when project is not active reverts
    function testInvestWhenProjectNotActiveReverts() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        // Close the project
        vm.prank(owner);
        stomatrade.closeProject(projectId);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidProject.selector));
        stomatrade.invest(TEST_CID, projectId, 1000 ether);
    }

    // Test invest when max funding exceeded
    function testInvestWhenMaxFundingExceeded() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            1000 ether,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        // First investment
        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 500 ether);

        // Try to invest more than remaining
        vm.prank(investor2);
        stomatrade.invest(TEST_CID, projectId, 1000 ether); // Only 500 ether should be accepted

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 1000 ether); // Should be exactly the maxInvested
    }

    // Test invest with multiple investors
    function testMultipleInvestors() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        vm.prank(investor2);
        stomatrade.invest(TEST_CID, projectId, 2000 ether);

        vm.prank(investor3);
        stomatrade.invest(TEST_CID, projectId, 2000 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 5000 ether);

        Investment memory inv1 = stomatrade.contribution(projectId, investor1);
        Investment memory inv2 = stomatrade.contribution(projectId, investor2);
        Investment memory inv3 = stomatrade.contribution(projectId, investor3);

        assertEq(inv1.amount, 1000 ether);
        assertEq(inv2.amount, 2000 ether);
        assertEq(inv3.amount, 2000 ether);
    }

    // Test invest updates to existing investment
    function testInvestUpdatesExistingInvestment() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Second investment by same investor
        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 500 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 1500 ether);

        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(investment.amount, 1500 ether); // Should be sum of both investments
    }

    // Test invest auto closes project when max funding reached
    function testInvestAutoClosesProjectWhenMaxFundingReached() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            1000 ether,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 1000 ether);
        assertEq(uint8(project.status), uint8(ProjectStatus.CLOSED));
    }

    // Test claimRefund function
    function testClaimRefund() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Refund the project
        vm.prank(owner);
        stomatrade.refundProject(projectId);

        uint256 balanceBefore = idrx.balanceOf(investor1);

        vm.prank(investor1);
        stomatrade.claimRefund(projectId);

        uint256 balanceAfter = idrx.balanceOf(investor1);
        assertEq(balanceAfter - balanceBefore, 1000 ether);

        // Check investment status updated
        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(uint8(investment.status), uint8(InvestmentStatus.CLAIMED));
        assertEq(investment.amount, 0);
    }

    // Test claimRefund reverts when project not in refund status
    function testClaimRefundRevertsWhenProjectNotInRefundStatus() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidState.selector));
        stomatrade.claimRefund(projectId);
    }

    // Test claimRefund reverts when no investment exists
    function testClaimRefundRevertsWhenNoInvestmentExists() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(owner);
        stomatrade.refundProject(projectId);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NothingToRefund.selector));
        stomatrade.claimRefund(projectId);
    }

    // Test claimRefund reverts when already claimed
    function testClaimRefundRevertsWhenAlreadyClaimed() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Refund the project
        vm.prank(owner);
        stomatrade.refundProject(projectId);

        vm.prank(investor1);
        stomatrade.claimRefund(projectId);

        // Try to claim again
        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NothingToRefund.selector));
        stomatrade.claimRefund(projectId);
    }

    // Test claimWithdraw function
    function testClaimWithdraw() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Calculate required deposit and approve tokens
        (uint256 totalPrincipal, uint256 totalInvestorProfit, uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(projectId);
        
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        // Finish the project
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        uint256 balanceBefore = idrx.balanceOf(investor1);

        vm.prank(investor1);
        stomatrade.claimWithdraw(projectId);

        uint256 balanceAfter = idrx.balanceOf(investor1);
        
        // Calculate expected return
        (uint256 expectedPrincipal, uint256 expectedProfit, uint256 expectedTotalReturn) = stomatrade.getInvestorReturn(projectId, investor1);
        assertEq(balanceAfter - balanceBefore, expectedTotalReturn);

        // Check investment status updated
        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(uint8(investment.status), uint8(InvestmentStatus.CLAIMED));
        assertEq(investment.amount, 0);
    }

    // Test claimWithdraw reverts when project not in success status
    function testClaimWithdrawRevertsWhenProjectNotInSuccessStatus() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidState.selector));
        stomatrade.claimWithdraw(projectId);
    }

    // Test claimWithdraw reverts when no investment exists
    function testClaimWithdrawRevertsWhenNoInvestmentExists() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        // Finish the project
        vm.prank(owner);
        uint256 totalRequired = 1000 ether + (1000 ether * 80 / 100); // principal + profit
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NothingToWithdraw.selector));
        stomatrade.claimWithdraw(projectId);
    }

    // Test claimWithdraw reverts when already claimed
    function testClaimWithdrawRevertsWhenAlreadyClaimed() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Calculate required deposit and approve tokens
        (uint256 totalPrincipal, uint256 totalInvestorProfit, uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(projectId);
        
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        // Finish the project
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        vm.prank(investor1);
        stomatrade.claimWithdraw(projectId);

        // Try to withdraw again
        vm.prank(investor1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NothingToWithdraw.selector));
        stomatrade.claimWithdraw(projectId);
    }

    // Test getProjectProfitBreakdown function
    function testGetProjectProfitBreakdown() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        (uint256 grossProfit, uint256 investorProfitPool, uint256 platformProfit) = stomatrade.getProjectProfitBreakdown(projectId);

        uint256 expectedGrossProfit = TEST_TOTAL_KILOS * TEST_PROFIT_PER_KILOS;
        uint256 expectedInvestorPool = (expectedGrossProfit * TEST_SHARED_PROFIT) / 100;
        uint256 expectedPlatformProfit = expectedGrossProfit - expectedInvestorPool;

        assertEq(grossProfit, expectedGrossProfit);
        assertEq(investorProfitPool, expectedInvestorPool);
        assertEq(platformProfit, expectedPlatformProfit);
    }

    // Test getInvestorReturn function for investor with investment
    function testGetInvestorReturn() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade.getInvestorReturn(projectId, investor1);

        assertEq(principal, 1000 ether);
        
        // Calculate expected profit
        (uint256 grossProfit, uint256 investorProfitPool, ) = stomatrade.getProjectProfitBreakdown(projectId);
        uint256 expectedProfit = (investorProfitPool * 1000 ether) / 1000 ether; // Since total raised is 1000 ether
        
        assertEq(profit, expectedProfit);
        assertEq(totalReturn, principal + profit);
    }

    // Test getInvestorReturn function for investor with no investment
    function testGetInvestorReturnForNonInvestor() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade.getInvestorReturn(projectId, nonInvestor);

        assertEq(principal, 0);
        assertEq(profit, 0);
        assertEq(totalReturn, 0);
    }

    // Test getAdminRequiredDeposit function
    function testGetAdminRequiredDeposit() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        (uint256 totalPrincipal, uint256 totalInvestorProfit, uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(projectId);

        assertEq(totalPrincipal, 1000 ether);
        
        // Calculate expected investor profit
        (uint256 grossProfit, uint256 investorProfitPool, ) = stomatrade.getProjectProfitBreakdown(projectId);
        assertEq(totalInvestorProfit, investorProfitPool);
        assertEq(totalRequired, totalPrincipal + totalInvestorProfit);
    }

    // Test all edge cases and error conditions
    function testAllEdgeCases() public {
        // Test with max values
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max,
            100  // shared profit can't be more than 100
        );

        // Test investing with max amount
        vm.startPrank(investor1);
        idrx.mint(investor1, type(uint256).max);
        idrx.approve(address(stomatrade), type(uint256).max);
        vm.stopPrank();

        vm.prank(investor1);
        vm.expectRevert(); // Should revert due to overflow in profit calculations
        stomatrade.invest(TEST_CID, projectId, type(uint256).max / 2);
    }

    // Test with 0 shared profit percentage
    function testProjectWithZeroSharedProfit() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            0  // 0% shared with investors
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Calculate required deposit and approve tokens
        (uint256 totalPrincipal, uint256 totalInvestorProfit, uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(projectId);
        
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        // Finish the project
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade.getInvestorReturn(projectId, investor1);
        assertEq(profit, 0); // No profit for investors if 0% shared
        assertEq(totalReturn, principal);
    }

    // Test with 100% shared profit
    function testProjectWithFullSharedProfit() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            100  // 100% shared with investors
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        (uint256 grossProfit, uint256 investorProfitPool, uint256 platformProfit) = stomatrade.getProjectProfitBreakdown(projectId);
        assertEq(platformProfit, 0); // 0 profit for platform
        assertEq(investorProfitPool, grossProfit); // Full profit to investors
    }

    // Test NFT functionality for farmers
    function testFarmerNFTFunctionality() public {
        vm.prank(owner);
        uint256 farmerId = stomatrade.addFarmer(
            TEST_CID,
            TEST_COLLECTOR_ID,
            TEST_FARMER_NAME,
            TEST_AGE,
            TEST_DOMICILE
        );

        // Test NFT ownerOf
        assertEq(stomatrade.ownerOf(farmerId), owner);
        
        // Test NFT tokenURI
        assertEq(stomatrade.tokenURI(farmerId), "https://gateway.pinata.cloud/ipfs/QmTestCID");
        
        // Test NFT name and symbol
        assertEq(stomatrade.name(), "Stomatrade");
        assertEq(stomatrade.symbol(), "STMX");
    }

    // Test multiple investments by same investor
    function testMultipleInvestmentsSameInvestorSameProject() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 500 ether);

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 300 ether);

        Project memory project = stomatrade.projects(projectId);
        assertEq(project.totalRaised, 800 ether);

        Investment memory investment = stomatrade.contribution(projectId, investor1);
        assertEq(investment.amount, 800 ether);
        assertEq(investment.id, 1); // Same investment ID since it's an update
    }

    // Test investing in multiple projects by same investor
    function testInvestingMultipleProjectsSameInvestor() public {
        vm.prank(owner);
        uint256 projectId1 = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(owner);
        uint256 projectId2 = stomatrade.createProject(
            TEST_CID,
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId1, 500 ether);

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId2, 300 ether);

        Project memory project1 = stomatrade.projects(projectId1);
        Project memory project2 = stomatrade.projects(projectId2);
        Investment memory inv1 = stomatrade.contribution(projectId1, investor1);
        Investment memory inv2 = stomatrade.contribution(projectId2, investor1);

        assertEq(project1.totalRaised, 500 ether);
        assertEq(project2.totalRaised, 300 ether);
        assertEq(inv1.amount, 500 ether);
        assertEq(inv2.amount, 300 ether);
        assertEq(inv1.id, 1);
        assertEq(inv2.id, 2);
    }
}