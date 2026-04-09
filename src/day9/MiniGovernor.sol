// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./GovernanceToken.sol";
import "./MiniTimelockController.sol";

contract MiniGovernor {
    GovernanceToken public immutable token;
    MiniTimelockController public immutable timelock;

    uint256 public immutable votingDelay;
    uint256 public immutable votingPeriod;
    uint256 public immutable proposalThreshold;
    uint256 public immutable quorum;

    uint256 public proposalCount;

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed,
        Canceled
    }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        string description;
        bytes32 descriptionHash;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool queued;
        bool executed;
        bool canceled;
        uint256 executeTime;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    error BelowProposalThreshold();
    error InvalidProposal();
    error ProposalNotActive();
    error AlreadyVoted();
    error InvalidSupport();
    error ProposalNotSucceeded();
    error ProposalNotQueued();
    error ProposalAlreadyExecuted();
    error ProposalCanceled();
    error ProposalAlreadyQueued();
    error OnlyProposer();

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 weight);
    event ProposalQueued(uint256 indexed proposalId, bytes32 indexed operationId, uint256 executeTime);
    event ProposalExecuted(uint256 indexed proposalId, bytes32 indexed operationId);
    event ProposalCancel(uint256 indexed proposalId);

    constructor(
        address _token,
        address _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) {
        token = GovernanceToken(_token);
        timelock = MiniTimelockController(payable(_timelock));
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external returns (uint256 proposalId) {
        if (token.balanceOf(msg.sender) < proposalThreshold) revert BelowProposalThreshold();

        proposalId = ++proposalCount;

        Proposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.target = target;
        p.value = value;
        p.data = data;
        p.description = description;
        p.descriptionHash = keccak256(bytes(description));
        p.startTime = block.timestamp + votingDelay;
        p.endTime = p.startTime + votingPeriod;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            description,
            p.startTime,
            p.endTime
        );
    }

    function castVote(uint256 proposalId, uint8 support) external {
        if (state(proposalId) != ProposalState.Active) revert ProposalNotActive();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        if (support > 2) revert InvalidSupport();

        Proposal storage p = proposals[proposalId];
        uint256 weight = token.balanceOf(msg.sender);

        hasVoted[proposalId][msg.sender] = true;

        if (support == 0) {
            p.againstVotes += weight;
        } else if (support == 1) {
            p.forVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert InvalidProposal();

        if (p.canceled) {
            return ProposalState.Canceled;
        }

        if (p.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < p.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= p.endTime) {
            return ProposalState.Active;
        }

        if (p.queued) {
            return ProposalState.Queued;
        }

        bool quorumReached = p.forVotes >= quorum;
        bool votePassed = p.forVotes > p.againstVotes;

        if (quorumReached && votePassed) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }

    function queue(uint256 proposalId) external returns (bytes32 operationId, uint256 executeTime) {
        if (state(proposalId) != ProposalState.Succeeded) revert ProposalNotSucceeded();

        Proposal storage p = proposals[proposalId];
        if (p.queued) revert ProposalAlreadyQueued();

        (operationId, executeTime) = timelock.schedule(
            p.target,
            p.value,
            p.data,
            p.descriptionHash
        );

        p.queued = true;
        p.executeTime = executeTime;

        emit ProposalQueued(proposalId, operationId, executeTime);
    }

    function execute(uint256 proposalId) external returns (bytes memory result) {
        if (state(proposalId) != ProposalState.Queued) revert ProposalNotQueued();

        Proposal storage p = proposals[proposalId];
        if (p.executed) revert ProposalAlreadyExecuted();

        bytes32 operationId = timelock.hashOperation(
            p.target,
            p.value,
            p.data,
            p.descriptionHash
        );

        result = timelock.execute(
            p.target,
            p.value,
            p.data,
            p.descriptionHash
        );

        p.executed = true;

        emit ProposalExecuted(proposalId, operationId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert InvalidProposal();
        if (msg.sender != p.proposer) revert OnlyProposer();
        if (p.executed) revert ProposalAlreadyExecuted();
        if (p.queued) revert ProposalAlreadyQueued();

        p.canceled = true;
        emit ProposalCancel(proposalId);
    }

    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert InvalidProposal();
        return (p.againstVotes, p.forVotes, p.abstainVotes);
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert InvalidProposal();
        return p;
    }

}