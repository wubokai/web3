// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MiniTimelockController {
    uint256 public immutable minDelay;
    address public admin;

    mapping(address => bool) public proposers;
    mapping(address => bool) public executors;
    mapping(bytes32 => uint256) public timestamps;
    mapping(bytes32 => bool) public done;

    error NotAdmin();
    error NotProposer();
    error NotExecutor();
    error AlreadyScheduled();
    error NotScheduled();
    error NotReady();
    error AlreadyDone();
    error CallFailed();

    event ProposerUpdated(address indexed account, bool allowed);
    event ExecutorUpdated(address indexed account, bool allowed);
    event Scheduled(
        bytes32 indexed operationId,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executeTime
    );
    event Cancelled(bytes32 indexed operationId);
    event Executed(bytes32 indexed operationId, address indexed target, uint256 value, bytes data);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyProposer() {
        if (!proposers[msg.sender]) revert NotProposer();
        _;
    }

    modifier onlyExecutor() {
        if (!executors[msg.sender]) revert NotExecutor();
        _;
    }

    constructor(uint256 _minDelay, address _admin) {
        minDelay = _minDelay;
        admin = _admin;
    }

    receive() external payable {}

    function setProposer(address account, bool allowed) external onlyAdmin {
        proposers[account] = allowed;
        emit ProposerUpdated(account, allowed);
    }

    function setExecutor(address account, bool allowed) external onlyAdmin {
        executors[account] = allowed;
        emit ExecutorUpdated(account, allowed);
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 descriptionHash
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, descriptionHash));
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) external onlyProposer returns (bytes32 operationId, uint256 executeTime) {
        operationId = hashOperation(target, value, data, descriptionHash);

        if (timestamps[operationId] != 0) revert AlreadyScheduled();

        executeTime = block.timestamp + minDelay;
        timestamps[operationId] = executeTime;

        emit Scheduled(operationId, target, value, data, executeTime);
    }

    function cancel(bytes32 operationId) external onlyAdmin {
        if (timestamps[operationId] == 0) revert NotScheduled();
        if (done[operationId]) revert AlreadyDone();

        delete timestamps[operationId];
        emit Cancelled(operationId);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) external payable onlyExecutor returns (bytes memory result) {
        bytes32 operationId = hashOperation(target, value, data, descriptionHash);

        uint256 executeTime = timestamps[operationId];
        if (executeTime == 0) revert NotScheduled();
        if (done[operationId]) revert AlreadyDone();
        if (block.timestamp < executeTime) revert NotReady();

        done[operationId] = true;

        (bool ok, bytes memory ret) = target.call{value: value}(data);
        if (!ok) revert CallFailed();

        emit Executed(operationId, target, value, data);
        return ret;
    }

    function isOperationPending(bytes32 operationId) external view returns (bool) {
        return timestamps[operationId] != 0 && !done[operationId] && block.timestamp < timestamps[operationId];
    }

    function isOperationReady(bytes32 operationId) external view returns (bool) {
        return timestamps[operationId] != 0 && !done[operationId] && block.timestamp >= timestamps[operationId];
    }

    function isOperationDone(bytes32 operationId) external view returns (bool) {
        return done[operationId];
    }
}