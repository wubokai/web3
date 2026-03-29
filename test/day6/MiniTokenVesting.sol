// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../src/day6/MockERC20.sol";
import "../../src/day6/MiniTokenVesting.sol";

contract MiniTokenVestingTest is Test {
    MockERC20 internal token;
    MiniTokenVesting internal vesting;

    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE1E);

    uint256 internal constant FUND_AMOUNT = 1_000_000e18;
    uint256 internal constant ALICE_VEST_AMOUNT = 1_000e18;

    function setUp() public {
        token = new MockERC20("Mock Token", "MTK");
        vesting = new MiniTokenVesting(address(token));

        token.mint(address(this), FUND_AMOUNT);
        token.transfer(address(vesting), 10_000e18);
    }


    function test_CreateVesting_Success() public {
        uint64 start = uint64(block.timestamp);
        uint64 cliff = 30 days;
        uint64 duration = 180 days;

        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, cliff, duration);

        
        MiniTokenVesting.VestingSchedule memory schedule = vesting.getSchedule(alice);

        assertEq(schedule.totalAmount, ALICE_VEST_AMOUNT);
        assertEq(schedule.released, 0);
        assertEq(schedule.start, start);
        assertEq(schedule.cliffDuration, cliff);
        assertEq(schedule.duration, duration);
        assertEq(schedule.initialized, true);
    }

    function test_CreateVesting_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenVesting.NotOwner.selector);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, uint64(block.timestamp), 30 days, 180 days);
    }

    function test_CreateVesting_RevertIfZeroAddress() public {
        vm.expectRevert(MiniTokenVesting.ZeroAddress.selector);
        vesting.createVesting(address(0), ALICE_VEST_AMOUNT, uint64(block.timestamp), 30 days, 180 days);
    }

    function test_CreateVesting_RevertIfAmountZero() public {
        vm.expectRevert(MiniTokenVesting.InvalidAmount.selector);
        vesting.createVesting(alice, 0, uint64(block.timestamp), 30 days, 180 days);
    }

    function test_CreateVesting_RevertIfDurationZero() public {
        vm.expectRevert(MiniTokenVesting.InvalidDuration.selector);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, uint64(block.timestamp), 30 days, 0);
    }

    function test_CreateVesting_RevertIfCliffGreaterThanDuration() public {
        vm.expectRevert(MiniTokenVesting.InvalidDuration.selector);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, uint64(block.timestamp), 181 days, 180 days);
    }

    function test_CreateVesting_RevertIfAlreadyExists() public {
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, uint64(block.timestamp), 30 days, 180 days);

        vm.expectRevert(MiniTokenVesting.VestingAlreadyExists.selector);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, uint64(block.timestamp), 30 days, 180 days);
    }

    function test_CreateVesting_RevertIfInsufficientFunding() public {
        MiniTokenVesting newVesting = new MiniTokenVesting(address(token));

        vm.expectRevert(MiniTokenVesting.InsufficientFunding.selector);
        newVesting.createVesting(alice, 100e18, uint64(block.timestamp), 1 days, 10 days);
    }

    function test_CreateVesting_RevertIfTotalAllocationsExceedFunding() public {
        vesting.createVesting(alice, 8_000e18, uint64(block.timestamp), 1 days, 10 days);

        vm.expectRevert(MiniTokenVesting.InsufficientFunding.selector);
        vesting.createVesting(bob, 3_000e18, uint64(block.timestamp), 1 days, 10 days);
    }

    function test_VestedAmount_BeforeCliff_IsZero() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        uint256 vested = vesting.vestedAmount(alice, block.timestamp + 10 days);
        assertEq(vested, 0);
    }

    function test_VestedAmount_AfterCliffAndBeforeEnd_IsLinear() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        uint256 t = block.timestamp + 90 days;
        uint256 vested = vesting.vestedAmount(alice, t);

        uint256 expected = (ALICE_VEST_AMOUNT * 90 days) / 180 days;
        assertEq(vested, expected);
    }

    function test_VestedAmount_AfterDuration_IsFullAmount() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        uint256 vested = vesting.vestedAmount(alice, block.timestamp + 200 days);
        assertEq(vested, ALICE_VEST_AMOUNT);
    }

    function test_ReleasableAmount_BeforeCliff_IsZero() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 20 days);
        assertEq(vesting.releasableAmount(alice), 0);
    }

    function test_Release_RevertBeforeCliff() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 20 days);

        vm.prank(alice);
        vm.expectRevert(MiniTokenVesting.NoTokensToRelease.selector);
        vesting.release();
    }

    function test_Release_RevertIfNoSchedule() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenVesting.VestingNotFound.selector);
        vesting.release();
    }

    function test_Release_AfterCliff_Works() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 90 days);

        uint256 expected = (ALICE_VEST_AMOUNT * 90 days) / 180 days;

        vm.prank(alice);
        vesting.release();

        assertEq(token.balanceOf(alice), expected);

        (
            uint256 totalAmount,
            uint256 released,
            ,
            ,
            ,
            bool initialized
        ) = vesting.vestings(alice);

        assertEq(totalAmount, ALICE_VEST_AMOUNT);
        assertEq(released, expected);
        assertEq(initialized, true);
        assertEq(vesting.totalAllocated(), ALICE_VEST_AMOUNT - expected);
    }

    function test_Release_MultipleTimes_NoDoubleClaim() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 90 days);
        uint256 firstExpected = (ALICE_VEST_AMOUNT * 90 days) / 180 days;

        vm.prank(alice);
        vesting.release();

        assertEq(token.balanceOf(alice), firstExpected);

        vm.warp(block.timestamp + 30 days);
        uint256 secondTotalVested = (ALICE_VEST_AMOUNT * 120 days) / 180 days;
        uint256 secondExpected = secondTotalVested - firstExpected;

        vm.prank(alice);
        vesting.release();

        assertEq(token.balanceOf(alice), firstExpected + secondExpected);

        (, uint256 released, , , , ) = vesting.vestings(alice);
        assertEq(released, firstExpected + secondExpected);
        assertEq(vesting.totalAllocated(), ALICE_VEST_AMOUNT - (firstExpected + secondExpected));
    }

    function test_Release_AllAfterEnd() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 200 days);

        vm.prank(alice);
        vesting.release();

        assertEq(token.balanceOf(alice), ALICE_VEST_AMOUNT);

        (, uint256 released, , , , ) = vesting.vestings(alice);
        assertEq(released, ALICE_VEST_AMOUNT);

        assertEq(vesting.releasableAmount(alice), 0);
        assertEq(vesting.totalAllocated(), 0);
    }

    function test_OnlyBeneficiaryCanReleaseOwnTokens() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 90 days);

        vm.prank(bob);
        vm.expectRevert(MiniTokenVesting.VestingNotFound.selector);
        vesting.release();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_ReleasableAmount_DecreasesAfterRelease() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 30 days, 180 days);

        vm.warp(block.timestamp + 100 days);

        uint256 beforeRelease = vesting.releasableAmount(alice);
        assertGt(beforeRelease, 0);

        vm.prank(alice);
        vesting.release();

        uint256 afterRelease = vesting.releasableAmount(alice);
        assertEq(afterRelease, 0);
    }

    function test_GetSchedule() public {
        uint64 start = uint64(block.timestamp);
        vesting.createVesting(alice, ALICE_VEST_AMOUNT, start, 15 days, 100 days);

        MiniTokenVesting.VestingSchedule memory schedule = vesting.getSchedule(alice);

        assertEq(schedule.totalAmount, ALICE_VEST_AMOUNT);
        assertEq(schedule.released, 0);
        assertEq(schedule.start, start);
        assertEq(schedule.cliffDuration, 15 days);
        assertEq(schedule.duration, 100 days);
        assertEq(schedule.initialized, true);
    }

}
