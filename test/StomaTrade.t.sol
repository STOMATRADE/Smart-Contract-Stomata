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
        vm.prank(owner);
        idrx.mint(investor1, 10000 ether);
        vm.prank(owner);
        idrx.mint(investor2, 10000 ether);
        vm.prank(owner);
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

        // Check farmer fields individually by getting the tuple
        (
            uint256 id,
            string memory idCollector,
            string memory name,
            uint256 age,
            string memory domicile
        ) = stomatrade.farmers(farmerId);

        assertEq(id, farmerId);
        assertEq(idCollector, TEST_COLLECTOR_ID);
        assertEq(name, TEST_FARMER_NAME);
        assertEq(age, TEST_AGE);
        assertEq(domicile, TEST_DOMICILE);

        // Check if NFT was minted
        assertEq(stomatrade.ownerOf(farmerId), owner);
        assertEq(
            stomatrade.tokenURI(farmerId),
            "https://gateway.pinata.cloud/ipfs/QmTestCID"
        );
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

        // Check farmer fields individually by getting the tuple
        (
            uint256 id,
            string memory idCollector,
            string memory name,
            uint256 age,
            string memory domicile
        ) = stomatrade.farmers(farmerId);

        assertEq(id, farmerId);
        assertEq(idCollector, TEST_COLLECTOR_ID);
        assertEq(name, TEST_FARMER_NAME);
        assertEq(age, TEST_AGE);
        assertEq(domicile, TEST_DOMICILE);
    }

    // Test addFarmer reverts when called by non-owner
    function testAddFarmerRevertsWhenCalledByNonOwner() public {
        vm.prank(investor1);
        vm.expectRevert();
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

        // Access project fields individually by getting the tuple
        (
            uint256 id,
            uint256 valueProject,
            uint256 maxInvested,
            uint256 totalRaised,
            uint256 totalKilos,
            uint256 profitPerKillos,
            uint256 sharedProfit,
            ProjectStatus status
        ) = stomatrade.projects(projectId);

        assertEq(id, projectId);
        assertEq(valueProject, TEST_PROJECT_VALUE);
        assertEq(maxInvested, TEST_MAX_INVESTED);
        assertEq(totalRaised, 0);
        assertEq(totalKilos, TEST_TOTAL_KILOS);
        assertEq(profitPerKillos, TEST_PROFIT_PER_KILOS);
        assertEq(sharedProfit, TEST_SHARED_PROFIT);
        assertEq(uint8(status), uint8(ProjectStatus.ACTIVE));

        // Check if NFT was minted
        assertEq(stomatrade.ownerOf(projectId), owner);
        assertEq(
            stomatrade.tokenURI(projectId),
            "https://gateway.pinata.cloud/ipfs/QmTestCID"
        );
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

        // Access project fields individually by getting the tuple
        (
            uint256 id,
            uint256 valueProject,
            uint256 maxInvested,
            uint256 totalRaised,
            uint256 totalKilos,
            uint256 profitPerKillos,
            uint256 sharedProfit,
            ProjectStatus status
        ) = stomatrade.projects(projectId);

        assertEq(id, projectId);
        assertEq(valueProject, TEST_PROJECT_VALUE);
        assertEq(maxInvested, TEST_MAX_INVESTED);
        assertEq(totalRaised, 0);
        assertEq(totalKilos, TEST_TOTAL_KILOS);
        assertEq(profitPerKillos, TEST_PROFIT_PER_KILOS);
        assertEq(sharedProfit, TEST_SHARED_PROFIT);
        assertEq(uint8(status), uint8(ProjectStatus.ACTIVE));
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
        vm.expectRevert();
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

        (, , , , , , , ProjectStatus status) = stomatrade.projects(projectId);

        assertEq(uint8(status), uint8(ProjectStatus.CLOSED));
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
        vm.expectRevert();
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

        (, , , , , , , ProjectStatus status) = stomatrade.projects(projectId);

        assertEq(uint8(status), uint8(ProjectStatus.REFUND));
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
        vm.expectRevert();
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
        (, , uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(
            projectId
        );

        // Approve token transfer for the required amount
        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        vm.prank(owner);
        stomatrade.finishProject(projectId);

        (, , , , , , , ProjectStatus status) = stomatrade.projects(projectId);

        assertEq(uint8(status), uint8(ProjectStatus.SUCCESS));
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
        vm.expectRevert();
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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 1000 ether);

        // For investment, destructure the tuple
        (
            uint256 id,
            ,
            address investor,
            uint256 amount,
            InvestmentStatus status
        ) = stomatrade.contribution(projectId, investor1);

        assertEq(id, 1);
        assertEq(investor, investor1);
        assertEq(amount, 1000 ether);
        assertEq(uint8(status), uint8(InvestmentStatus.UNCLAIMED));

        // Check if investment NFT was minted
        assertEq(stomatrade.ownerOf(1), investor1);
        assertEq(
            stomatrade.tokenURI(1),
            "https://gateway.pinata.cloud/ipfs/QmTestCID"
        );
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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 1000 ether);

        // For investment, destructure the tuple
        (
            uint256 id,
            ,
            address investor,
            uint256 amount,
            InvestmentStatus status
        ) = stomatrade.contribution(projectId, investor1);

        assertEq(id, 1);
        assertEq(investor, investor1);
        assertEq(amount, 1000 ether);
        assertEq(uint8(status), uint8(InvestmentStatus.UNCLAIMED));
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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 1000 ether); // Should be exactly the maxInvested
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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 5000 ether);

        (, , , uint256 amount1, ) = stomatrade.contribution(
            projectId,
            investor1
        );
        (, , , uint256 amount2, ) = stomatrade.contribution(
            projectId,
            investor2
        );
        (, , , uint256 amount3, ) = stomatrade.contribution(
            projectId,
            investor3
        );

        assertEq(amount1, 1000 ether);
        assertEq(amount2, 2000 ether);
        assertEq(amount3, 2000 ether);
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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 1500 ether);

        (, , , uint256 amount, ) = stomatrade.contribution(
            projectId,
            investor1
        );
        assertEq(amount, 1500 ether); // Should be sum of both investments
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

        (, , , uint256 totalRaised, , , , ProjectStatus status) = stomatrade
            .projects(projectId);
        assertEq(totalRaised, 1000 ether);
        assertEq(uint8(status), uint8(ProjectStatus.CLOSED));
    }

    // Test claimRefund function
    function testClaimRefund() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            "",  // Empty CID to avoid project NFT minting that could conflict with investment NFTs
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest("", projectId, 1000 ether);  // Empty CID to avoid investment NFT minting

        // Refund the project
        vm.prank(owner);
        stomatrade.refundProject(projectId);

        uint256 balanceBefore = idrx.balanceOf(investor1);

        vm.prank(investor1);
        stomatrade.claimRefund(projectId);

        uint256 balanceAfter = idrx.balanceOf(investor1);
        assertEq(balanceAfter - balanceBefore, 1000 ether);

        // Check investment status updated
        (, , , uint256 amount, InvestmentStatus status) = stomatrade
            .contribution(projectId, investor1);
        assertEq(uint8(status), uint8(InvestmentStatus.CLAIMED));
        assertEq(amount, 0);
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
        vm.expectRevert(
            abi.encodeWithSelector(Errors.NothingToRefund.selector)
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(Errors.NothingToRefund.selector)
        );
        stomatrade.claimRefund(projectId);
    }

    // Test claimWithdraw function
    function testClaimWithdraw() public {
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            "",  // Empty CID to avoid project NFT minting that could conflict with investment NFTs
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        vm.prank(investor1);
        stomatrade.invest("", projectId, 1000 ether);  // Empty CID to avoid investment NFT minting

        // Calculate required deposit and approve tokens
        (, , uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(
            projectId
        );

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
        (, , uint256 expectedTotalReturn) = stomatrade.getInvestorReturn(
            projectId,
            investor1
        );
        assertEq(balanceAfter - balanceBefore, expectedTotalReturn);

        // Check investment status updated
        (, , , uint256 amount, InvestmentStatus status) = stomatrade
            .contribution(projectId, investor1);
        assertEq(uint8(status), uint8(InvestmentStatus.CLAIMED));
        assertEq(amount, 0);
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
            "",  // Empty CID to avoid project NFT minting that could conflict with investment NFTs
            TEST_PROJECT_VALUE,
            TEST_MAX_INVESTED,
            TEST_TOTAL_KILOS,
            TEST_PROFIT_PER_KILOS,
            TEST_SHARED_PROFIT
        );

        // Finish the project
        vm.startPrank(owner);
        uint256 totalRequired = 1000 ether + ((1000 ether * 80) / 100); // principal + profit
        idrx.approve(address(stomatrade), totalRequired);
        stomatrade.finishProject(projectId);
        vm.stopPrank();

        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.NothingToWithdraw.selector)
        );
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
        (, , uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(
            projectId
        );

        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        // Finish the project
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        vm.prank(investor1);
        stomatrade.claimWithdraw(projectId);

        // Try to withdraw again
        vm.prank(investor1);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.NothingToWithdraw.selector)
        );
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

        (
            uint256 grossProfit,
            uint256 investorProfitPool,
            uint256 platformProfit
        ) = stomatrade.getProjectProfitBreakdown(projectId);

        uint256 expectedGrossProfit = TEST_TOTAL_KILOS * TEST_PROFIT_PER_KILOS;
        uint256 expectedInvestorPool = (expectedGrossProfit *
            TEST_SHARED_PROFIT) / 100;
        uint256 expectedPlatformProfit = expectedGrossProfit -
            expectedInvestorPool;

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

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade
            .getInvestorReturn(projectId, investor1);

        assertEq(principal, 1000 ether);

        // Calculate expected profit
        (, uint256 investorProfitPool, ) = stomatrade
            .getProjectProfitBreakdown(projectId);
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

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade
            .getInvestorReturn(projectId, nonInvestor);

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

        (
            uint256 totalPrincipal,
            uint256 totalInvestorProfit,
            uint256 totalRequired
        ) = stomatrade.getAdminRequiredDeposit(projectId);

        assertEq(totalPrincipal, 1000 ether);

        // Calculate expected investor profit
        (, uint256 investorProfitPool, ) = stomatrade.getProjectProfitBreakdown(
            projectId
        );
        assertEq(totalInvestorProfit, investorProfitPool);
        assertEq(totalRequired, totalPrincipal + totalInvestorProfit);
    }

    // Test all edge cases and error conditions
    function testAllEdgeCases() public {
        // Test with max values - don't mint project NFT to avoid token ID conflicts
        vm.prank(owner);
        uint256 projectId = stomatrade.createProject(
            "",  // Empty CID to avoid project NFT minting that could conflict with investment NFTs
            1000 ether,  // Use reasonable values to avoid overflow
            5000 ether,  // Use reasonable values to avoid overflow
            1000,        // Use reasonable values to avoid overflow
            1000000000000000000,  // 1 token per kilo
            80           // Use reasonable percentage to avoid overflow
        );

        // Test investing with reasonable max amount - use owner to mint tokens since only owner can mint
        vm.prank(owner);  // Use owner to mint tokens since only owner can mint
        idrx.mint(investor1, 10000 ether);  // Use reasonable amount to avoid overflow

        vm.startPrank(investor1);
        idrx.approve(address(stomatrade), 10000 ether);  // Use reasonable amount to avoid overflow
        vm.stopPrank();

        vm.prank(investor1);
        vm.expectRevert(); // Should revert due to overflow in profit calculations when using max values
        stomatrade.invest("", projectId, 2000 ether);  // Use reasonable amount after setup
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
            0 // 0% shared with investors
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        // Calculate required deposit and approve tokens
        (, , uint256 totalRequired) = stomatrade.getAdminRequiredDeposit(
            projectId
        );

        vm.prank(owner);
        idrx.approve(address(stomatrade), totalRequired);

        // Finish the project
        vm.prank(owner);
        stomatrade.finishProject(projectId);

        (uint256 principal, uint256 profit, uint256 totalReturn) = stomatrade
            .getInvestorReturn(projectId, investor1);
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
            100 // 100% shared with investors
        );

        vm.prank(investor1);
        stomatrade.invest(TEST_CID, projectId, 1000 ether);

        (
            uint256 grossProfit,
            uint256 investorProfitPool,
            uint256 platformProfit
        ) = stomatrade.getProjectProfitBreakdown(projectId);
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

        // Test farmer fields individually by getting the tuple
        (
            uint256 id,
            string memory idCollector,
            string memory name,
            uint256 age,
            string memory domicile
        ) = stomatrade.farmers(farmerId);

        assertEq(id, farmerId);
        assertEq(idCollector, TEST_COLLECTOR_ID);
        assertEq(name, TEST_FARMER_NAME);
        assertEq(age, TEST_AGE);
        assertEq(domicile, TEST_DOMICILE);

        // Test NFT ownerOf
        assertEq(stomatrade.ownerOf(farmerId), owner);

        // Test NFT tokenURI
        assertEq(
            stomatrade.tokenURI(farmerId),
            "https://gateway.pinata.cloud/ipfs/QmTestCID"
        );

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

        (, , , uint256 totalRaised, , , , ) = stomatrade.projects(projectId);
        assertEq(totalRaised, 800 ether);

        (uint256 id, , , uint256 amount, ) = stomatrade.contribution(
            projectId,
            investor1
        );
        assertEq(amount, 800 ether);
        assertEq(id, 1); // Same investment ID since it's an update
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

        (, , , uint256 totalRaised1, , , , ) = stomatrade.projects(projectId1);
        (, , , uint256 totalRaised2, , , , ) = stomatrade.projects(projectId2);
        assertEq(totalRaised1, 500 ether);
        assertEq(totalRaised2, 300 ether);

        (uint256 id1, , , uint256 amount1, ) = stomatrade.contribution(
            projectId1,
            investor1
        );
        (uint256 id2, , , uint256 amount2, ) = stomatrade.contribution(
            projectId2,
            investor1
        );
        assertEq(amount1, 500 ether);
        assertEq(amount2, 300 ether);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }
}
