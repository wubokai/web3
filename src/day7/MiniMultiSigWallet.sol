// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MiniMultiSigWallet {
    struct Transaction{
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numApprovals;
    }

    address[] public owners;
    mapping(address=>bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 =>mapping(address=>bool)) public approved;

    error NotOwner();
    error InvalidRequirement();
    error InvalidOwner();
    error OwnerNotUnique();
    error TxDoesNotExist();
    error TxAlreadyExecuted();
    error TxAlreadyApproved();
    error TxNotApproved();
    error NotEnoughApprovals();
    error TxExecutionFailed();

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txId,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ApproveTransaction(address indexed owner, uint256 indexed txId);
    event RevokeApproval(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(address indexed owner, uint256 indexed txId);

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier txExists(uint256 txId) {
        if (txId >= transactions.length) revert TxDoesNotExist();
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert TxAlreadyExecuted();
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        uint256 len = _owners.length;
        if (len == 0) revert InvalidRequirement();
        if (_required == 0 || _required > len) revert InvalidRequirement();
        
        for(uint256 i =0; i< len; i++){
            address owner = _owners[i];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert OwnerNotUnique();

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner{
        uint256 txId = transactions.length;

        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                numApprovals: 0
            })
        );

        emit SubmitTransaction(msg.sender, txId, to, value, data);
    }

    function approveTransaction(uint256 txId)
        external onlyOwner txExists(txId) notExecuted(txId){
            if(approved[txId][msg.sender]) revert TxAlreadyApproved();

            approved[txId][msg.sender] = true;
            transactions[txId].numApprovals += 1;

            emit ApproveTransaction(msg.sender, txId);
    }

    function revokeApproval(uint256 txId)
        external onlyOwner txExists(txId) notExecuted(txId){
            if(!approved[txId][msg.sender]) revert TxNotApproved();
            
            approved[txId][msg.sender] = false;
            transactions[txId].numApprovals -= 1;
            emit RevokeApproval(msg.sender, txId);
    }

    function executeTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage t = transactions[txId];

        if(t.numApprovals<required) revert NotEnoughApprovals();
        t.executed = true;

        (bool ok, ) = t.to.call{value: t.value}(t.data);
        if(!ok) revert TxExecutionFailed();

        emit ExecuteTransaction(msg.sender, txId);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 txId
    )
        external
        view
        txExists(txId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numApprovals
        )
    {
        Transaction memory txn = transactions[txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.numApprovals);
    }


}