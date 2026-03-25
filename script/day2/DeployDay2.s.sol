// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import {MiniERC721} from "../../src/day2/MiniERC721.sol";
import {NFTSale} from "../../src/day2/NFTSale.sol";

contract DeployDay2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MiniERC721 nft = new MiniERC721("Selby NFT", "SNFT");
        NFTSale sale = new NFTSale(address(nft), 0.01 ether);

        vm.stopBroadcast();

        console2.log("MiniERC721 deployed at:", address(nft));
        console2.log("NFTSale deployed at:", address(sale));
    }
}