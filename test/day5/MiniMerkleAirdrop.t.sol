// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import {MiniERC20} from "../../src/day5/MiniERC20.sol";
import {MiniMerkleAirdrop} from "../../src/day5/MiniMerkleAirdrop.sol";

contract MiniMerkleAirdropTest is Test {
    MiniERC20 token;
    MiniMerkleAirdrop airdrop;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address charlie = address(0xCA11);
    address david = address(0xDAD1);
    address eve = address(0xE5E);
            
    uint256 aliceAmount = 100e18;
    uint256 bobAmount = 200e18;
    uint256 charlieAmount = 300e18;
    uint256 davidAmount = 400e18;

    bytes32 aliceLeaf;
    bytes32 bobLeaf;
    bytes32 charlieLeaf;
    bytes32 davidLeaf;

    bytes32 root;

    event Claimed(address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event Withdrawn(address indexed to, uint256 amount);

    function setUp() public {
        token = new MiniERC20("Selby Token", "STK");

        aliceLeaf = _leaf(alice, aliceAmount);
        bobLeaf = _leaf(bob, bobAmount);
        charlieLeaf = _leaf(charlie, charlieAmount);
        davidLeaf = _leaf(david, davidAmount);

        bytes32 leftNode = _hashPair(aliceLeaf, bobLeaf);
        bytes32 rightNode = _hashPair(charlieLeaf, davidLeaf);
        root = _hashPair(leftNode, rightNode);

        airdrop = new MiniMerkleAirdrop(address(token), root);

        token.mint(address(airdrop), 1000e18);    
        
    }

    function test_ClaimSuccess() public {
        bytes32[] memory proof = getAliceProof();

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Claimed(alice, aliceAmount);
        airdrop.claim(alice, aliceAmount, proof);

        assertEq(token.balanceOf(alice), aliceAmount);
        assertTrue(airdrop.claimed(alice));
    }

    function test_RevertIf_AlreadyClaimed() public {
        bytes32[] memory proof = getAliceProof();

        vm.prank(alice);
        airdrop.claim(alice, aliceAmount, proof);

        vm.prank(alice);
        vm.expectRevert(MiniMerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(alice, aliceAmount, proof);
    }

    function test_RevertIf_InvalidProof() public {
        bytes32[] memory wrongProof = new bytes32[](2);
        wrongProof[0] = charlieLeaf;
        wrongProof[1] = _hashPair(aliceLeaf, bobLeaf);

        vm.prank(alice);
        vm.expectRevert(MiniMerkleAirdrop.InvalidProof.selector);
        airdrop.claim(alice, aliceAmount, wrongProof);
    }

    function test_RevertIf_WrongAmount() public {
        bytes32[] memory proof = getAliceProof();

        vm.prank(alice);
        vm.expectRevert(MiniMerkleAirdrop.InvalidProof.selector);
        airdrop.claim(alice, 999e18, proof);
    }

    function test_RevertIf_WrongAccount() public {
        bytes32[] memory proof = getAliceProof();

        vm.prank(eve);
        vm.expectRevert(MiniMerkleAirdrop.InvalidProof.selector);
        airdrop.claim(eve, aliceAmount, proof);
    }

    function test_UpdateMerkleRoot_OnlyOwner() public {
        bytes32 newRoot = bytes32(uint256(123456));

        vm.prank(alice);
        vm.expectRevert(MiniMerkleAirdrop.NotOwner.selector);
        airdrop.updateMerkleRoot(newRoot);
    }

    function test_UpdateMerkleRoot_Success() public {
        bytes32 newRoot = bytes32(uint256(888888));

        vm.expectEmit(false, false, false, true);
        emit MerkleRootUpdated(root, newRoot);

        airdrop.updateMerkleRoot(newRoot);

        assertEq(airdrop.merkleRoot(), newRoot);
    }

    function test_WithdrawRemaining_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(MiniMerkleAirdrop.NotOwner.selector);
        airdrop.withdrawRemaining(alice, 100e18);
    }

    function test_WithdrawRemaining_Success() public {
        uint256 ownerBalBefore = token.balanceOf(owner);

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(owner, 100e18);

        airdrop.withdrawRemaining(owner, 100e18);

        assertEq(token.balanceOf(owner), ownerBalBefore + 100e18);
    }

    function test_RevertIf_ClaimZeroAddress() public {
        bytes32[] memory proof = getAliceProof();

        vm.expectRevert(MiniMerkleAirdrop.ZeroAddress.selector);
        airdrop.claim(address(0), aliceAmount, proof);
    }

    function test_RevertIf_WithdrawToZeroAddress() public {
        vm.expectRevert(MiniMerkleAirdrop.ZeroAddress.selector);
        airdrop.withdrawRemaining(address(0), 1e18);
    }
    
    function test_BobClaimSuccess() public {
        bytes32[] memory proof = getBobProof();

        vm.prank(bob);
        airdrop.claim(bob, bobAmount, proof);

        assertEq(token.balanceOf(bob), bobAmount);
        assertTrue(airdrop.claimed(bob));
    }

    function test_UpdateMerkleRoot_StartsNewClaimRound() public {
        bytes32[] memory proof = getAliceProof();

        vm.prank(alice);
        airdrop.claim(alice, aliceAmount, proof);

        bytes32 newRoot = _leaf(alice, 50e18);
        airdrop.updateMerkleRoot(newRoot);

        assertFalse(airdrop.claimed(alice));

        vm.prank(alice);
        airdrop.claim(alice, 50e18, new bytes32[](0));

        assertEq(token.balanceOf(alice), aliceAmount + 50e18);
        assertTrue(airdrop.claimed(alice));
    }
    
    function getAliceProof() public view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = bobLeaf;
        proof[1] = _hashPair(charlieLeaf, davidLeaf);
    }

    function getBobProof() public view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = aliceLeaf;
        proof[1] = _hashPair(charlieLeaf, davidLeaf);
    }

    function getCharlieProof() public view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = davidLeaf;
        proof[1] = _hashPair(aliceLeaf, bobLeaf);
    }

    function getDavidProof() public view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = charlieLeaf;
        proof[1] = _hashPair(aliceLeaf, bobLeaf);
    }
    
    function _leaf(address account, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(bytes.concat(a, b))
            : keccak256(bytes.concat(b, a));
    }


}
