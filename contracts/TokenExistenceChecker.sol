// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721 {
    function getDate(uint256 tokenId) external view returns (uint256);
}

contract TokenExistenceChecker {
    IERC721 private tokenContract;

    constructor(address _tokenAddress) {
        tokenContract = IERC721(_tokenAddress);
    }

    function getNoExistentTokenId(uint256 from, uint256 to) public view returns (uint256) {
        uint256 emptyId = 0;
        for (uint256 i = from; i <= to; i++){
            uint256 date = tokenContract.getDate(i);
            if(date == 0){
                emptyId = i;
                break ;
            }
        }
        return emptyId;
    
    }
}
