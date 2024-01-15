// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract MockERC721 is ERC721 {

    uint256 public tokenId;

    constructor() ERC721("Mock", "Mock") {}

    function claim() external {
        _safeMint(msg.sender, ++tokenId);
    }
}
