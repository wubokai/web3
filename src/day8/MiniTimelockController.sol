// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MiniTimelockController {
    address public admin;
    uint256 public minDelay;

    // operation id => execute timestamp
    mapping(bytes32 => uint256) public timestamps;
    mapping(bytes32 => bool) public executed;

    error NotAdmin();
    error ZeroAddress();
    error InvalidDelay();
    error InvalidExecuteTime();
    error OperationAlreadyQueued();
    error OperationNotQueued();
    error OperationAlreadyExecuted();
    error OperationNotReady();
    error CallFailed();

    event OperationScheduled(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executeTime
    );

    event OperationExecuted(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        bytes result
    );

    event OperationCanceled(bytes32 indexed id);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address _admin, uint256 _minDelay) {
        if (_admin == address(0)) revert ZeroAddress();
        if (_minDelay == 0) revert InvalidDelay();

        admin = _admin;
        minDelay = _minDelay;
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 executeTime
    ) public pure returns(bytes32) {
        return keccak256(abi.encode(target,value,data,executeTime));
    }

    function isQueued(bytes32 id) public view returns(bool) {
        return timestamps[id] != 0;
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 executeTime
    ) external onlyAdmin returns (bytes32 id) {
        if(target == address(0)) revert ZeroAddress();
        if(executeTime<block.timestamp + minDelay) revert InvalidDelay();

        id = hashOperation(target, value, data, executeTime);

        if(timestamps[id] != 0) revert OperationAlreadyQueued();
        if(executed[id]) revert OperationAlreadyExecuted();

        timestamps[id] = executeTime;

        emit OperationScheduled(id, target, value, data, executeTime);
        
    }

    function cancel(bytes32 id) external onlyAdmin {
        if(timestamps[id] == 0) revert OperationNotQueued();
        if(executed[id]) revert OperationAlreadyExecuted();

        delete timestamps[id];

        emit OperationCanceled(id);

    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 executeTime
    ) external payable returns(bytes memory result){
        bytes32 id = hashOperation(target, value, data, executeTime);

        uint256 queuedTime = timestamps[id];
        if (queuedTime == 0) revert OperationNotQueued();
        if (executed[id]) revert OperationAlreadyExecuted();
        if (block.timestamp < queuedTime) revert OperationNotReady();

        executed[id] = true;
        delete timestamps[id];

        (bool ok, bytes memory ret) = target.call{value: value}(data);
        if(!ok) revert CallFailed();

        emit OperationExecuted(id, target, value, data, ret);
        return ret;
    }


    receive() external payable{}
}