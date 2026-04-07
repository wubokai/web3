// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../src/day8/MiniTimelockController.sol";

contract TestTarget {
    uint256 public number;
    uint256 public received;
    string public text;

    event TargetCalled(address caller, uint256 value, uint256 number, string text);

    function setNumber(uint256 n) external payable {
        number = n;
        received += msg.value;
        emit TargetCalled(msg.sender, msg.value, n, text);
    }

    function setText(string calldata t) external {
        text = t;
    }

    function willRevert() external pure {
        revert("target reverted");
    }
}

contract MiniTimelockControllerTest is Test {
    MiniTimelockController timelock;
    TestTarget target;

    address admin = address(0xA11CE);
    address user = address(0xB0B);
    uint256 constant MIN_DELAY = 1 days;

    function setUp() public {
        vm.prank(admin);
        timelock = new MiniTimelockController(admin, MIN_DELAY);

        target = new TestTarget();

        vm.deal(address(timelock), 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
    }

    function testConstructor() public view {
        assertEq(timelock.admin(), admin);
        assertEq(timelock.minDelay(), MIN_DELAY);
    }

    function testConstructorRevertIfAdminZero() public {
        vm.expectRevert(MiniTimelockController.ZeroAddress.selector);
        new MiniTimelockController(address(0), MIN_DELAY);
    }

    function testConstructorRevertIfDelayZero() public {
        vm.expectRevert(MiniTimelockController.InvalidDelay.selector);
        new MiniTimelockController(admin, 0);
    }

    function testNonAdminCannotSchedule() public {
        uint256 executeTime = block.timestamp + MIN_DELAY;

        vm.prank(user);
        vm.expectRevert(MiniTimelockController.NotAdmin.selector);
        timelock.schedule(address(target), 0, abi.encodeCall(TestTarget.setNumber, (123)), executeTime);
    }

    function testCannotScheduleWithShortDelay() public {
        uint256 executeTime = block.timestamp + MIN_DELAY - 1;

        vm.prank(admin);
        vm.expectRevert(MiniTimelockController.InvalidExecuteTime.selector);
        timelock.schedule(address(target), 0, abi.encodeCall(TestTarget.setNumber, (123)), executeTime);
    }

    function testScheduleSuccess() public {
        uint256 executeTime = block.timestamp + MIN_DELAY;
        bytes memory data = abi.encodeCall(TestTarget.setNumber, (123));

        bytes32 expectedId = keccak256(abi.encode(address(target), 0, data, executeTime));

        vm.prank(admin);
        bytes32 id = timelock.schedule(address(target), 0, data, executeTime);

        assertEq(id, expectedId);
        assertEq(timelock.timestamps(id), executeTime);
        assertTrue(timelock.isQueued(id));
        assertFalse(timelock.executed(id));
    }

    function testCannotScheduleSameOperationTwice() public {
        uint256 executeTime = block.timestamp + MIN_DELAY;
        bytes memory data = abi.encodeCall(TestTarget.setNumber, (123));

        vm.startPrank(admin);
        timelock.schedule(address(target), 0, data, executeTime);

        vm.expectRevert(MiniTimelockController.OperationAlreadyQueued.selector);
        timelock.schedule(address(target), 0, data, executeTime);
        vm.stopPrank();
    }

    function testExecuteTwiceRevertsAsAlreadyExecuted() public {
        uint256 executeTime = block.timestamp + MIN_DELAY;
        bytes memory data = abi.encodeCall(TestTarget.setNumber, (123));

        vm.prank(admin);
        timelock.schedule(address(target), 0, data, executeTime);

        vm.warp(executeTime);
        timelock.execute(address(target), 0, data, executeTime);

        vm.expectRevert(MiniTimelockController.OperationAlreadyExecuted.selector);
        timelock.execute(address(target), 0, data, executeTime);
    }

    function testCannotCancelExecutedOperation() public {
        uint256 executeTime = block.timestamp + MIN_DELAY;
        bytes memory data = abi.encodeCall(TestTarget.setNumber, (123));
        bytes32 id = keccak256(abi.encode(address(target), 0, data, executeTime));

        vm.prank(admin);
        timelock.schedule(address(target), 0, data, executeTime);

        vm.warp(executeTime);
        timelock.execute(address(target), 0, data, executeTime);

        vm.prank(admin);
        vm.expectRevert(MiniTimelockController.OperationAlreadyExecuted.selector);
        timelock.cancel(id);
    }
}
