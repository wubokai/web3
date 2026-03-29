// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MiniERC20} from "./MiniERC20.sol";
import {MerkleProof} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract MiniMerkleAirdrop {
    MiniERC20 public immutable token;
    bytes32 public merkleRoot;
    address public owner;

    mapping(bytes32 => mapping(address => bool)) private claimedByRoot;

    error NotOwner();
    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();
    error ZeroAddress();

    event Claimed(address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address _token, bytes32 _merkleRoot){
        if(_token == address(0)) revert ZeroAddress();
        token =MiniERC20(_token);
        merkleRoot = _merkleRoot;
        owner = msg.sender;
    }

    modifier onlyOwner(){
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function claimed(address account) public view returns (bool) {
        return claimedByRoot[merkleRoot][account];
    }

    function claim(address account, uint256 amount, bytes32[] calldata proof) external {
        if(account == address(0)) revert ZeroAddress();
        bytes32 currentRoot = merkleRoot;
        if(claimedByRoot[currentRoot][account]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account,amount))));
        bool ok = MerkleProof.verify(proof, currentRoot, leaf);
        if(!ok) revert InvalidProof();

        claimedByRoot[currentRoot][account] = true;

        bool success = token.transfer(account, amount);
        if(!success) revert TransferFailed();

        emit Claimed(account, amount);
    }

    function updateMerkleRoot(bytes32 newRoot) external onlyOwner{
        bytes32 old = merkleRoot;
        merkleRoot = newRoot;

        emit MerkleRootUpdated(old, newRoot);
    }

    function withdrawRemaining(address to, uint256 amount) external onlyOwner{
        if(to == address(0)) revert ZeroAddress();

        bool ok = token.transfer(to, amount);
        if(!ok) revert TransferFailed();
    
        emit Withdrawn(to, amount);
    }

}
