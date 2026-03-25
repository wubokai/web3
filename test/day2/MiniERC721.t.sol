// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import {MiniERC721} from "../../src/day2/MiniERC721.sol";
import {MockERC721Receiver} from "./mocks/MockERC721Receiver.sol";
import {BadReceiver} from "./mocks/BadReceiver.sol";

contract MiniERC721Test is Test {

    MiniERC721 internal nft;
    MockERC721Receiver internal goodReceiver;
    BadReceiver internal badReceiver;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0FFEE);
    address internal operator = address(0x11);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        nft = new MiniERC721("Mini NFT", "MNFT");
        goodReceiver = new MockERC721Receiver();
        badReceiver = new BadReceiver();
    }

    function test_Mint() public {
        nft.mint(alice, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_MintEmitsTransfer() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, 1);

        nft.mint(alice, 1);
    }

    function test_RevertIf_MintToZeroAddress() public {
        vm.expectRevert(MiniERC721.ZeroAddress.selector);
        nft.mint(address(0), 1);
    }

    function test_RevertIf_MintDuplicateTokenId() public {
        nft.mint(alice, 1);

        vm.expectRevert(MiniERC721.TokenAlreadyMinted.selector);
        nft.mint(bob, 1);
    }

    function test_ApproveByOwner() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        assertEq(nft.getApproved(1), bob);
    }

    function test_ApproveEmitsEvent() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1);
        nft.approve(bob, 1);
    }

    function test_RevertIf_ApproveByNonOwnerNonOperator() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(MiniERC721.NotAuthorized.selector);
        nft.approve(charlie, 1);
    }

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        nft.setApprovalForAll(operator, true);

        assertTrue(nft.isApprovedForAll(alice, operator));
    }

    function test_SetApprovalForAllEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, operator, true);
        nft.setApprovalForAll(operator, true);
    }

    function test_OperatorCanTransfer() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_OwnerCanTransfer() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_ApprovedAddressCanTransfer() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.transferFrom(alice, charlie, 1);

        assertEq(nft.ownerOf(1), charlie);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(charlie), 1);
    }

    function test_RevertIf_NonAuthorizedTransfer() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(MiniERC721.NotAuthorized.selector);
        nft.transferFrom(alice, bob, 1);
    }

    function test_TransferClearsSingleTokenApproval() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);

        vm.prank(alice);
        nft.transferFrom(alice, charlie, 1);

        assertEq(nft.getApproved(1), address(0));
    }

    function test_RevertIf_TransferWrongFrom() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(MiniERC721.InvalidFrom.selector);
        nft.transferFrom(bob, charlie, 1);
    }

    function test_RevertIf_TransferToZeroAddress() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(MiniERC721.InvalidTo.selector);
        nft.transferFrom(alice, address(0), 1);
    }

    function test_BurnByOwner() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.burn(1);

        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.ownerOf(1), address(0));
    }

    function test_BurnByApprovedAddress() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.burn(1);

        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.ownerOf(1), address(0));
        assertEq(nft.getApproved(1), address(0));
    }

    function test_RevertIf_BurnByUnauthorized() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(MiniERC721.NotAuthorized.selector);
        nft.burn(1);
    }

    function test_SafeTransferToEOA() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function test_SafeTransferToGoodReceiver() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(goodReceiver), 1);

        assertEq(nft.ownerOf(1), address(goodReceiver));
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(address(goodReceiver)), 1);
    }

    function test_RevertIf_SafeTransferToBadReceiver() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(MiniERC721.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(badReceiver), 1);
    }

}