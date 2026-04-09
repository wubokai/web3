// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/forge-std/src/Test.sol";

import "../../src/day9/GovernanceToken.sol";
import "../../src/day9/MiniTimelockController.sol";
import "../../src/day9/MiniGovernor.sol";
import "../../src/day9/Box.sol";

contract MiniGovernorTest is Test {
    GovernanceToken token;
    MiniTimelockController timelock;
    MiniGovernor governor;
    Box box;

    address admin = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA701);
    address dave = address(0xDA7E);

    uint256 constant VOTING_DELAY = 1 days;
    uint256 constant VOTING_PERIOD = 3 days;
    uint256 constant PROPOSAL_THRESHOLD = 100 ether;
    uint256 constant QUORUM = 300 ether;
    uint256 constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
        token = new GovernanceToken();
        timelock = new MiniTimelockController(TIMELOCK_DELAY, admin);
        governor = new MiniGovernor(
            address(token),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM
        );
        box = new Box(address(timelock));

        timelock.setProposer(address(governor), true);
        timelock.setExecutor(address(governor), true);

        token.mint(alice, 200 ether);
        token.mint(bob, 150 ether);
        token.mint(carol, 200 ether);
        token.mint(dave, 50 ether);
    }

    function _createProposal(uint256 newValue, string memory description) internal returns (uint256 proposalId) {
        bytes memory data = abi.encodeWithSelector(Box.setValue.selector, newValue);

        vm.prank(alice);
        proposalId = governor.propose(address(box), 0, data, description);
    }

    function _moveToActive(uint256 proposalId) internal {
        MiniGovernor.Proposal memory p = governor.getProposal(proposalId);
        vm.warp(p.startTime);
        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Active));
    }

    function _movePastVoting(uint256 proposalId) internal {
        MiniGovernor.Proposal memory p = governor.getProposal(proposalId);
        vm.warp(p.endTime + 1);
    }

    function test_Propose_Success() public {
        uint256 proposalId = _createProposal(123, "set value to 123");

        MiniGovernor.Proposal memory p = governor.getProposal(proposalId);

        assertEq(p.proposer, alice);
        assertEq(p.target, address(box));
        assertEq(p.value, 0);
        assertEq(p.forVotes, 0);
        assertEq(p.againstVotes, 0);
        assertEq(p.abstainVotes, 0);
        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Pending));
    }

    function test_Propose_RevertIfBelowThreshold() public {
        bytes memory data = abi.encodeWithSelector(Box.setValue.selector, 123);

        vm.prank(dave);
        vm.expectRevert(MiniGovernor.BelowProposalThreshold.selector);
        governor.propose(address(box), 0, data, "should fail");
    }

    function test_CastVote_Success() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // for

        vm.prank(bob);
        governor.castVote(proposalId, 0); // against

        vm.prank(carol);
        governor.castVote(proposalId, 2); // abstain

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(forVotes, 200 ether);
        assertEq(againstVotes, 150 ether);
        assertEq(abstainVotes, 200 ether);
    }

    function test_CastVote_RevertIfNotActive() public {
        uint256 proposalId = _createProposal(123, "set value to 123");

        vm.prank(alice);
        vm.expectRevert(MiniGovernor.ProposalNotActive.selector);
        governor.castVote(proposalId, 1);
    }

    function test_CastVote_RevertIfAlreadyVoted() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.prank(alice);
        vm.expectRevert(MiniGovernor.AlreadyVoted.selector);
        governor.castVote(proposalId, 1);
    }

    function test_CastVote_RevertIfInvalidSupport() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        vm.expectRevert(MiniGovernor.InvalidSupport.selector);
        governor.castVote(proposalId, 3);
    }

    function test_State_Succeeded() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // 200

        vm.prank(carol);
        governor.castVote(proposalId, 1); // 200

        vm.prank(bob);
        governor.castVote(proposalId, 0); // 150

        _movePastVoting(proposalId);

        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Succeeded));
    }

    function test_State_Defeated_WhenForVotesNotEnoughForQuorum() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // 200

        vm.prank(bob);
        governor.castVote(proposalId, 0); // 150

        _movePastVoting(proposalId);

        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Defeated));
    }

    function test_State_Defeated_WhenAgainstWins() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // 200

        vm.prank(bob);
        governor.castVote(proposalId, 0); // 150

        vm.prank(carol);
        governor.castVote(proposalId, 0); // 200

        _movePastVoting(proposalId);

        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Defeated));
    }

    function test_Queue_Success() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.prank(carol);
        governor.castVote(proposalId, 1);

        _movePastVoting(proposalId);

        (bytes32 operationId, uint256 executeTime) = governor.queue(proposalId);

        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Queued));
        assertEq(timelock.timestamps(operationId), executeTime);
    }

    function test_Queue_RevertIfNotSucceeded() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // only 200, quorum not reached

        _movePastVoting(proposalId);

        vm.expectRevert(MiniGovernor.ProposalNotSucceeded.selector);
        governor.queue(proposalId);
    }

    function test_Execute_Success() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1); // 200

        vm.prank(carol);
        governor.castVote(proposalId, 1); // 200

        _movePastVoting(proposalId);

        (, uint256 executeTime) = governor.queue(proposalId);

        vm.warp(executeTime);

        governor.execute(proposalId);

        assertEq(box.value(), 123);
        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Executed));
    }

    function test_Execute_RevertIfNotQueued() public {
        uint256 proposalId = _createProposal(123, "set value to 123");

        vm.expectRevert(MiniGovernor.ProposalNotQueued.selector);
        governor.execute(proposalId);
    }

    function test_Execute_RevertIfTimelockNotReady() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.prank(carol);
        governor.castVote(proposalId, 1);

        _movePastVoting(proposalId);

        governor.queue(proposalId);

        vm.expectRevert(MiniTimelockController.NotReady.selector);
        governor.execute(proposalId);
    }

    function test_Execute_RevertIfExecutedTwice() public {
        uint256 proposalId = _createProposal(123, "set value to 123");
        _moveToActive(proposalId);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.prank(carol);
        governor.castVote(proposalId, 1);

        _movePastVoting(proposalId);

        (, uint256 executeTime) = governor.queue(proposalId);
        vm.warp(executeTime);

        governor.execute(proposalId);

        vm.expectRevert(MiniGovernor.ProposalNotQueued.selector);
        governor.execute(proposalId);
    }

    function test_Cancel_SuccessBeforeQueue() public {
        uint256 proposalId = _createProposal(123, "set value to 123");

        vm.prank(alice);
        governor.cancel(proposalId);

        assertEq(uint256(governor.state(proposalId)), uint256(MiniGovernor.ProposalState.Canceled));
    }

    function test_Cancel_RevertIfNotProposer() public {
        uint256 proposalId = _createProposal(123, "set value to 123");

        vm.prank(bob);
        vm.expectRevert(MiniGovernor.OnlyProposer.selector);
        governor.cancel(proposalId);
    }
}