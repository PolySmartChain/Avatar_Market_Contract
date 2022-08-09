// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token//ERC20/ERC20.sol";

contract Market is EIP712("Market", "1"), Ownable{

    using ECDSA for bytes32;
    using SafeMath for uint256;
    bytes32 private constant STRUCT_BUY =
    keccak256("Buy(uint256 tokenId,uint256 price,uint256 payKind,uint256 timestamp)");

    event Buy(uint256 indexed tokenId, address indexed benefit, address indexed seller, uint256 price, uint256 fee, uint256 payKind);

    event CancelListing(address indexed owner, uint256 indexed tokenId, uint256 price, uint256 payKind);

    address public polyJetClub;

    uint256 public expiredAfter;

    bool public disabled;

    mapping(bytes => uint256) public _signatureOff;

    mapping(uint256 => address) public _payCountTokenMapping;

    mapping(address => uint256) public _payTokenCountMapping;

    uint256 public payTokenCount = 1;

    uint256 public _fee = 500;

    address payable payAddr;

    address public admin;

    constructor(
        address polyJetClub_,
        uint256 expiredAfter_,
        address payable addr_
    ) {
        polyJetClub = polyJetClub_;
        expiredAfter = expiredAfter_;
        transferOwnership(addr_);
        payAddr = addr_;
    }

    function setExpiredAfter(uint256 e) external onlyOwner {
        expiredAfter = e;
    }

    function setDisabled(bool b) external onlyOwner {
        disabled = b;
    }

    function setPayAddr(address payable addr_) external onlyOwner {
        payAddr = addr_;
    }

    function setAdmin(address addr_) external onlyOwner {
        admin = addr_;
    }

    function setFee(uint256 fee) external onlyOwner {
        _fee = fee;
    }

    function setPayToken(address payToken) external onlyOwner {
        require(_payTokenCountMapping[payToken] < 1, "PAYTOKEN EXIST");
        _payTokenCountMapping[payToken] = payTokenCount;
        _payCountTokenMapping[payTokenCount] = payToken;
        payTokenCount = payTokenCount.add(1);
    }

    function removePayToken(address payToken) external onlyOwner {
        require(_payTokenCountMapping[payToken] >= 1, "PAYTOKEN NOT EXIST");
        _payCountTokenMapping[_payTokenCountMapping[payToken]] = address(0);
        _payTokenCountMapping[payToken] = 0;
    }

    // 1. if user set approve for this contract
    // 2. verify the signature
    function buy(uint256 tokenId, uint256 price, uint256 timestamp, address to, uint256 payKind, bytes calldata signature) external payable {
        require(_signatureOff[signature] != 1, "SIGN OFF");
        require(!disabled, "DISABLED");
        if(payKind == 0){
            require(msg.value == price, "PRICE");
        }
        require(!Address.isContract(msg.sender) && !Address.isContract(to), "CONTRACT");
        require(block.timestamp >= timestamp && block.timestamp - timestamp <= expiredAfter, "EXPIRED");
        bytes32 d = _hashTypedDataV4(
            keccak256(
                abi.encode(STRUCT_BUY, tokenId, price, payKind, timestamp)
            )
        );
        address payable o = payable(IERC721(polyJetClub).ownerOf(tokenId));
        require(o == d.recover(signature), "EC");
        uint256 fee = price.mul(_fee).div(10000);
        if(payKind == 0){
            Address.sendValue(o, price.sub(fee));
            Address.sendValue(payAddr, fee);
        }else{
            IERC20(_payCountTokenMapping[payKind]).transferFrom(msg.sender, o, price.sub(fee));
            IERC20(_payCountTokenMapping[payKind]).transferFrom(msg.sender, payAddr, fee);
        }
        IERC721(polyJetClub).transferFrom(o, to, tokenId);
        _signatureOff[signature] = 1;
        emit Buy(tokenId, to, o, price, fee, payKind);
    }

    function cancelListing(uint256 tokenId, uint256 price, uint256 payKind, uint256 timestamp, bytes calldata signature) external {
        require(_signatureOff[signature] != 1, "SIGN HAS OFF");
        require(!disabled, "DISABLED");
        bytes32 d = _hashTypedDataV4(
            keccak256(
                abi.encode(STRUCT_BUY, tokenId, price, payKind, timestamp)
            )
        );
        require(msg.sender == d.recover(signature), "EC");
        _signatureOff[signature] = 1;
        emit CancelListing(msg.sender, tokenId, price, payKind);
    }

    function isSignatureValid(uint256 tokenId, uint256 price, uint256 payKind, uint256 timestamp, address user, bytes calldata signature) public view returns (bool) {
        if(_signatureOff[signature] == 1){
            return false;
        }
        bytes32 d = _hashTypedDataV4(
            keccak256(
                abi.encode(STRUCT_BUY, tokenId, price, payKind, timestamp)
            )
        );
        return user == d.recover(signature);
    }

    function setSignatureOff(bytes calldata signature) external {
        require(msg.sender == admin, "ADMIN ERROR");
        _signatureOff[signature] = 1;
    }

}