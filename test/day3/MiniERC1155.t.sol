// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import {MiniERC1155} from "../../src/day3/MiniERC1155.sol";

contract MiniERC1155Test is Test {
    MiniERC1155 token;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address charlie = address(0xCA11);

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

    function setUp() public {
        token = new MiniERC1155("ipfs://base/");
    }

    function test_Mint() public {
        token.mint(alice, 1, 10);

        assertEq(token.balanceOf(1, alice), 10);
    }

    function test_RevertIf_NonOwnerMint() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC1155.NotOwner.selector);
        token.mint(alice, 1, 10);
    }

    function test_SetApprovalForAll() public {
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function test_OwnerCanTransferOwnToken() public {
        token.mint(alice, 1, 10);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 4, "");

        assertEq(token.balanceOf(1, alice), 6);
        assertEq(token.balanceOf(1, bob), 4);
    }

    function test_OperatorCanTransfer() public {
        token.mint(alice, 1, 10);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, 1, 3, "");

        assertEq(token.balanceOf(1, alice), 7);
        assertEq(token.balanceOf(1, charlie), 3);
    }

    function test_RevertIf_NotAuthorized() public {
        token.mint(alice, 1, 10);

        vm.prank(bob);
        vm.expectRevert(MiniERC1155.NotAuthorized.selector);
        token.safeTransferFrom(alice, charlie, 1, 3, "");
    }

    function test_RevertIf_InsufficientBalance() public {
        token.mint(alice, 1, 2);

        vm.prank(alice);
        vm.expectRevert(MiniERC1155.InsufficientBalance.selector);
        token.safeTransferFrom(alice, bob, 1, 5, "");
    }

    function test_SafeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 10;
        amounts[1] = 20;

        token.mintBatch(alice, ids, amounts);

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(1, alice), 0);
        assertEq(token.balanceOf(2, alice), 0);
        assertEq(token.balanceOf(1, bob), 10);
        assertEq(token.balanceOf(2, bob), 20);
    }

    function test_RevertIf_BatchLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](1);

        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 10;

        vm.prank(alice);
        vm.expectRevert(MiniERC1155.LengthMismatch.selector);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        amounts[0] = 10;
        amounts[1] = 20;
        amounts[2] = 30;

        token.mintBatch(alice, ids, amounts);

        assertEq(token.balanceOf(1, alice), 10);
        assertEq(token.balanceOf(2, alice), 20);
        assertEq(token.balanceOf(3, alice), 30);
    }

    function test_Burn() public {
        token.mint(alice, 1, 10);

        vm.prank(alice);
        token.burn(alice, 1, 4);

        assertEq(token.balanceOf(1, alice), 6);
    }

    function test_TransferSingleEventOnMint() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), alice, 1, 10);

        token.mint(alice, 1, 10);
    }

    function test_TransferBatchEventOnMintBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 11;
        amounts[1] = 22;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(owner, address(0), alice, ids, amounts);

        token.mintBatch(alice, ids, amounts);
    }

    function test_TransferSingleEventOnTransfer() public {
        token.mint(alice, 1, 10);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, 1, 3);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 3, "");
    }
}
