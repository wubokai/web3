// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Receiver} from "./interfaces/IERC721Receiver.sol";

contract MiniERC721 {
    string public name;
    string public symbol;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    error ZeroAddress();
    error TokenAlreadyMinted();
    error TokenNotMinted();
    error NotOwner();
    error NotAuthorized();
    error InvalidFrom();
    error InvalidTo();
    error UnsafeRecipient();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator,bool approved);

    constructor(string memory _name, string memory _symbol){
        name = _name;
        symbol = _symbol;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf[tokenId];

        if(owner == address(0)) revert TokenNotMinted();
        if(msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[tokenId] = to;
        emit Approval(owner, to, tokenId);

    }

    function setApprovalForAll(address operator, bool approved) external {
        if(operator == address(0)) revert ZeroAddress();

        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public{
        if(! _isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();
        _transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf[tokenId];
        if (owner == address(0)) revert TokenNotMinted();

        return (
            spender == owner
                || getApproved[tokenId] == spender
                || isApprovedForAll[owner][spender]
        );
    }

    



    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();
        _transfer(from, to, tokenId);

        if(! _checkOnERC721Received(msg.sender, from, to, tokenId, data)) revert UnsafeRecipient();

    }

    function mint(address to, uint256 tokenId) external{
        if(to == address(0)) revert ZeroAddress();
        if (ownerOf[tokenId] != address(0)) revert TokenAlreadyMinted();

        balanceOf[to] += 1;
        ownerOf[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) external {
        address owner = ownerOf[tokenId];
        if (owner == address(0)) revert TokenNotMinted();

        if(!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();
        delete getApproved[tokenId];
        balanceOf[owner] -= 1;
        delete ownerOf[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }    
    
    
    function _transfer(address from, address to, uint256 tokenId) internal {
        address owner = ownerOf[tokenId];
        if(owner == address(0)) revert TokenNotMinted();
        if(owner != from) revert InvalidFrom();
        if(to == address(0)) revert InvalidTo();
    
        delete getApproved[tokenId];

        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    
    }


    function _checkOnERC721Received(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal returns (bool) {
        if (to.code.length == 0) {
            return true;
        }

        try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }


} 