// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MiniERC1155 {
    address public owner;
    string public uri;
    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    error NotOwner();
    error NotAuthorized();
    error LengthMismatch();
    error ZeroAddress();
    error InsufficientBalance();

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    constructor(string memory _uri){
        owner = msg.sender;
        uri = _uri;
    }

    modifier onlyOwner(){
        if(msg.sender != owner) revert NotOwner();
        _;
    }

    function setURI(string memory newUri) external onlyOwner {
        uri = newUri;
        emit URI(newUri, 0);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata /* data */
    ) external {
        if(to == address(0)) revert ZeroAddress();
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }

        uint256 fromBal = balanceOf[id][from];
        if(fromBal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[id][from] = fromBal - amount;
        }
        balanceOf[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata /* data */
    ) external {
        if(to == address(0)) revert ZeroAddress();
        if (ids.length != amounts.length) revert LengthMismatch();
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBal = balanceOf[id][from];
            if(fromBal < amount) revert InsufficientBalance();

            unchecked {
                balanceOf[id][from] = fromBal - amount;
            }
            balanceOf[id][to] += amount;

        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();

        balanceOf[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (ids.length != amounts.length) revert LengthMismatch();

        for(uint i= 0;i<ids.length;i++){
            balanceOf[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }

        uint256 fromBal = balanceOf[id][from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[id][from] = fromBal - amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);

    }


}
