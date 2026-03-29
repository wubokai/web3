// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import "../../lib/forge-std/src/console2.sol";
import {MiniERC20} from "../../src/day5/MiniERC20.sol";
import {MiniMerkleAirdrop} from "../../src/day5/MiniMerkleAirdrop.sol";

contract DeployDay5 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MiniERC20 token = new MiniERC20("Selby Token", "STK");

        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        MiniMerkleAirdrop airdrop = new MiniMerkleAirdrop(address(token), merkleRoot);
        token.mint(address(airdrop), 1_000_000 ether);

        vm.stopBroadcast();

        console2.log("MiniERC20 deployed at:", address(token));
        console2.log("MiniMerkleAirdrop deployed at:", address(airdrop));
        console2.logBytes32(merkleRoot);
    }

}
