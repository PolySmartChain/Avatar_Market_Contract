// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

library TokenDetector {
    // ERC165 Interface ID for ERC721: 0x80ac58cd
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    // ERC165 Interface ID for ERC1155: 0xd9b67a26
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    function isERC721(address _addr) internal view returns (bool) {
        (bool success, bytes memory data) = _addr.staticcall(
            abi.encodeWithSignature("supportsInterface(bytes4)", INTERFACE_ID_ERC721)
        );
        return (success && data.length >= 32 && abi.decode(data, (bool)));
    }

    function isERC1155(address _addr) internal view returns (bool) {
        (bool success, bytes memory data) = _addr.staticcall(
            abi.encodeWithSignature("supportsInterface(bytes4)", INTERFACE_ID_ERC1155)
        );
        return (success && data.length >= 32 && abi.decode(data, (bool)));
    }


    function isERC20(address _addr) internal view returns (bool) {
        (bool successTotalSupply, bytes memory dataTotalSupply) = _addr.staticcall(
            abi.encodeWithSignature("totalSupply()")
         );
        (bool successBalanceOf, bytes memory dataBalanceOf) = _addr.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
         (bool successDecimals, bytes memory dataDecimals) = _addr.staticcall(
            abi.encodeWithSignature("decimals()")
        );

        return (successTotalSupply && dataTotalSupply.length >= 32) &&
           (successBalanceOf && dataBalanceOf.length >= 32) &&
           (successDecimals && dataDecimals.length >= 32);
    }


}

