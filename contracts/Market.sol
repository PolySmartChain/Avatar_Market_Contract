// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract Market is EIP712("Market", "1"), Ownable {

    using ECDSA for bytes32;
    using SafeMath for uint256;

    struct Sign {
        address from;
        address nft;
        uint256 tokenId;
        uint256 amount;
        address token;
        uint256 price;
        uint256 timestamp;
    }

    bytes32 private constant STRUCT_BUY =
        keccak256("Buy(address from,address nft,uint256 tokenId,uint256 amount,address token,uint256 price,uint256 timestamp)");

    uint256 public expiredAfter = 30 days;
    uint256 public fee = 500;

    bool public lock;
    address payable public payAddr;

    mapping(address => uint256) public nftMapping;// 0=null, 1=EIP721, 2=EIP1155

    mapping(bytes => bool) public signatureOff;

    mapping(address => bool) public tokenMapping;// prc20

    event Buy(address indexed from, address indexed nft, uint256 tokenId, uint256 amount, address token, uint256 price, uint256 timestamp, address to);
    event CancelList(address from, bytes signature);

    modifier locking() {
        require(!lock, "Locking");
        _;
    }

    constructor(
        address[] memory _nfts,
        address[] memory _tokens,
        address payable _payAddress
    ) Ownable() {
        for (uint256 i; i < _nfts.length; i++) {
            nftMapping[_nfts[i]] = 1;
        }
        for (uint256 j; j < _tokens.length; j++) {
            tokenMapping[_tokens[j]] = true;
        }
        payAddr = _payAddress;
    }

    function setExpiredAfter(uint256 e) external onlyOwner {
        expiredAfter = e;
    }

    function setLock(bool _lock) external onlyOwner {
        lock = _lock;
    }

    function setPayAddr(address payable addr_) external onlyOwner {
        payAddr = addr_;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setNFT(address _nft, uint256 state) external onlyOwner {
        require(state < 3, "Abnormal nft address");
        nftMapping[_nft] = state;
    }

    function setPayToken(address payToken, bool state) external onlyOwner {
        require(payToken != address(0), "Token is zero address");
        tokenMapping[payToken] = state;
    }

    function buy(
        Sign calldata sign,
        address to,
        bytes calldata signature
    ) external payable locking {
        uint256 state = nftMapping[sign.nft];
        require(state > 0, "Abnormal nft address");
        require(!signatureOff[signature], "Signature already exist");
        require(sign.from != to, "Repeat purchase");
        require(sign.amount > 0 && sign.price > 0, "Parameter is zero");
        require(block.timestamp >= sign.timestamp && block.timestamp - sign.timestamp <= expiredAfter, "Signature expired");

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(STRUCT_BUY, sign.from, sign.nft, sign.tokenId, sign.amount, sign.token, sign.price, sign.timestamp)
            )
        );
        address signer = digest.recover(signature);
        require(sign.from == signer, "Abnormal signature");

        // fee
        uint256 f = sign.price.mul(fee).div(10000);
        uint256 income = sign.price.sub(f);
        if (sign.token == address(0)) {// psc
            require(msg.value == sign.price, "Abnormal price");
            Address.sendValue(payable(sign.from), income);
            Address.sendValue(payAddr, f);
        } else {
            IERC20(sign.token).transferFrom(msg.sender, sign.from, income);
            IERC20(sign.token).transferFrom(msg.sender, payAddr, f);
        }

        //nft
        if (state == 1) {// erc721
            IERC721(sign.nft).safeTransferFrom(sign.from, to, sign.tokenId);
        } else {
            IERC1155(sign.nft).safeTransferFrom(sign.from, to, sign.tokenId, sign.amount, "");
        }

        signatureOff[signature] = true;

        emit Buy(sign.from, sign.nft, sign.tokenId, sign.amount, sign.token, sign.price, sign.timestamp, to);
    }

    function cancelList(
        Sign calldata sign,
        bytes calldata signature
    ) external locking {
        require(sign.from == msg.sender, "");
        require(!signatureOff[signature], "Signature already exist");

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(STRUCT_BUY, sign.from, sign.nft, sign.tokenId, sign.amount, sign.token, sign.price, sign.timestamp)
            )
        );
        address signer = digest.recover(signature);
        require(sign.from == signer, "Abnormal signature");

        signatureOff[signature] = true;

        emit CancelList(sign.from, signature);
    }
}
