// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Receiver} from "../../../src/day2/interfaces/IERC721Receiver.sol";

contract MockERC721Receiver is IERC721Receiver {
    event Received(address operator, address from, uint256 tokenId, bytes data);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        emit Received(operator, from, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }
}