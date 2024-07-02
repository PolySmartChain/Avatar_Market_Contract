// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721 {
    function getDate(uint256 tokenId) external view returns (uint256);
}

interface Proxys {
    function hasMint(uint256[] calldata tokenIds) external view returns (bool);
}

contract TokenExistenceChecker {
    IERC721 private tokenContract;
    Proxys private proxysContract;

    constructor(address _tokenAddress, address _proxys) {
        tokenContract = IERC721(_tokenAddress);
        proxysContract = Proxys(_proxys);
    }

    function getNoExistentTokenId(uint256 from, uint256 to) public view returns (uint256) {
        uint256 emptyId = 0;
        for (uint256 i = from; i <= to; i++){
            uint256 date = tokenContract.getDate(i);
            uint256[] memory array = new uint256[](1);
            array[0] = i;
            bool hasMint = proxysContract.hasMint(array);
            if(date == 0 && hasMint == true){
                emptyId = i;
                break ;
            }
        }
        return emptyId;
    
    }
}
