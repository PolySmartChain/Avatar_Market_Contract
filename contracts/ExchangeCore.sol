// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./libs/TokenDetector.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract ExchangeCore is OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, ERC165, IERC721Receiver, IERC1155Receiver {

    using SafeMath for uint256;

    struct orderInfo {
        uint256 orderId; // order
        address nftToken; // nft token address
        uint256 tokenId; // tokenID
        address seller; // seller address
        address payToken; // erc20 token address, address(0) -> native token
        uint256 price;  // selling price
        uint256 amount; // ERC721 = 1, ERC1155 = Multiple
        uint256 creationTime; // create timestamp
        uint256 status; // 0 normal  1 takeOff  2 buy
        address buyer; // buyer
        uint256 updateTime; // takeOff / buy time
    }

    struct orderParams {
        address nftToken; // nft token address
        uint256 tokenId; // tokenID
        address payToken; // erc20 token address, address(0) -> native token
        uint256 price;  // selling price
        uint256 amount; // ERC721 = 1, ERC1155 = Multiple
    }

    uint256 private counter;

    mapping(address => uint) public nftType;  // 1 = ERC721, 2 = ERC1155

    mapping(address => uint256[]) public orderIdList;  // nft -> orderId list
    mapping(uint256 => orderInfo) public orderIdInfo;  // orderId -> orderInfo

    mapping(uint256 => bool) public orderIdExist;  // orderId is exist
    mapping(uint256 => uint256) public orderIdIndex;  // orderId in orderIdList index

    mapping(address => uint256[]) public userOrder;  // user order
    mapping(uint256 => uint256) private  userOrderIndex;  // orderId index in userOrder

    mapping(address => mapping(uint256 => uint256[])) public orderIdSearch;
    mapping(uint256 => uint256) private  searchIndex;  // orderId index in orderIdSearch

    uint256 public fee; // 500 / 10000
    address public socialVault; // social vault address


    event PutOnSale(address indexed seller, uint256 orderId, address nftToken, uint256 tokenId, address payToken, uint256 price, uint256 amount, uint256 creationTime);
    event TakeOffSale(address indexed seller, uint256 orderId, uint256 takeOffTime);
    event UpdatePrice(address indexed seller, uint256 orderId, address payToken, uint256 price, uint256 updateTime);
    event Buy(address indexed buyer, uint256 orderId, uint256 buyTime);


    function initialize(address _socialVault) public initializer {
        counter = 0;
        fee = 500;
        socialVault = _socialVault;
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function setFee(uint256 _fee) public  onlyOwner{
        require(_fee >= 0 && _fee <= 10000, "setFee: invalid fee");
        fee = _fee;
    }


    function setSocialVault(address _addr) public  onlyOwner{
        socialVault = _addr;
    }


    function generateUniqueOrderId(address seller) private returns (uint256) {
        counter++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, seller, counter)));
    }


    function putOnSale(orderParams calldata order) public nonReentrant{

        require(TokenDetector.isERC721(order.nftToken) || TokenDetector.isERC1155(order.nftToken) , "putOnSale: invalid nft address");
        require(order.payToken == address(0) || TokenDetector.isERC20(order.payToken), "putOnSale: invalid payToken address");
        require(order.amount > 0 , "putOnSale: order amount = 0");
        require(order.price > 0 , "putOnSale: order price = 0");

        if (TokenDetector.isERC721(order.nftToken)){
            require(order.amount == 1 , "putOnSale: invalid erc721 amount");
            IERC721(order.nftToken).safeTransferFrom(_msgSender(), address(this), order.tokenId);
            nftType[order.nftToken] = 1;
        }else {
            IERC1155(order.nftToken).safeTransferFrom(_msgSender(), address(this), order.tokenId, order.amount, "");
            nftType[order.nftToken] = 2;
        }

        orderInfo memory newOrder = orderInfo({
        orderId: generateUniqueOrderId(_msgSender()),
        nftToken: order.nftToken,
        tokenId: order.tokenId,
        seller: _msgSender(),
        payToken: order.payToken,
        price: order.price,
        amount: order.amount,
        creationTime: block.timestamp,
        status: 0,
        buyer: address(0),
        updateTime: block.timestamp
        });

        orderIdList[order.nftToken].push(newOrder.orderId); // 添加订单id到对应nft订单列表数组里
        orderIdInfo[newOrder.orderId] = newOrder; // 订单id对应的订单信息
        userOrder[_msgSender()].push(newOrder.orderId); // 添加用户拥有的订单id
        orderIdExist[newOrder.orderId] = true; // 设置订单号存在

        orderIdSearch[order.nftToken][order.tokenId].push(newOrder.orderId); // 添加订单id到指定nft根据tokenId搜索数组里

        uint256 orderIdListLength = orderIdList[order.nftToken].length;
        orderIdIndex[newOrder.orderId] = orderIdListLength - 1; // 设置订单id在对应的数组里的索引

        uint256 userOrderLength = userOrder[_msgSender()].length;
        userOrderIndex[newOrder.orderId] = userOrderLength - 1; // 设置订单id在用户订单数组里的索引
   
        uint256 orderIdSearchLength = orderIdSearch[order.nftToken][order.tokenId].length;
        searchIndex[newOrder.orderId] = orderIdSearchLength - 1; // 设置订单id在用户订单数组里的索引

        emit PutOnSale(newOrder.seller, newOrder.orderId, newOrder.nftToken, newOrder.tokenId, newOrder.payToken, newOrder.price, newOrder.amount, newOrder.creationTime);

    }

    function deleteOrder(orderInfo memory order) private {

        uint256 _orderId = order.orderId;

        // 移除订单列表
        uint256 orderIndex = orderIdIndex[_orderId];
        uint256 maxOrderIndex = orderIdList[order.nftToken].length - 1;

        if (orderIndex < maxOrderIndex){
            uint256 replaceId = orderIdList[order.nftToken][maxOrderIndex];
            orderIdList[order.nftToken][orderIndex] = replaceId;
            orderIdIndex[replaceId] = orderIndex;
             orderIdList[order.nftToken].pop();
        }else {
            orderIdIndex[_orderId] = 0;
            orderIdList[order.nftToken].pop();
        }

        // 移除用户订单列表
        uint256 userIndex = userOrderIndex[_orderId];
        uint256 maxUserOrderIndex = userOrder[order.seller].length - 1;

        if (userIndex < maxUserOrderIndex){
            uint256 maxOrderId = userOrder[order.seller][maxUserOrderIndex];
            orderInfo memory maxInfo = orderIdInfo[maxOrderId];
            userOrder[order.seller][userIndex] = maxOrderId;
            userOrderIndex[maxInfo.orderId] = userIndex;
            userOrder[order.seller].pop();
        }else {
            userOrderIndex[_orderId] = 0;
            userOrder[order.seller].pop();
        }

        
        // 移除搜索列表
        uint256 secIndex = searchIndex[_orderId];
        uint256 maxSecIndex = orderIdSearch[order.nftToken][order.tokenId].length - 1;

        if (secIndex < maxSecIndex){
            uint256 maxSearchOrderId = orderIdSearch[order.nftToken][order.tokenId][maxSecIndex];
            orderIdSearch[order.nftToken][order.tokenId][secIndex] = maxSearchOrderId;
            searchIndex[maxSearchOrderId] = secIndex;
            orderIdSearch[order.nftToken][order.tokenId].pop();
        }else {
            searchIndex[_orderId] = 0;
            orderIdSearch[order.nftToken][order.tokenId].pop();
        }
        
        // 设置订单存在状态
        orderIdExist[_orderId] = false;

    }

    function takeOffSale(uint256 _orderId) public nonReentrant{
        require(orderIdExist[_orderId] , "takeOffSale: orderId is not exist");
        orderInfo storage order = orderIdInfo[_orderId];
        require(order.seller == _msgSender() , "takeOffSale: sender is not seller");

        order.status = 1;
        order.updateTime = block.timestamp;
        deleteOrder(order);

        if(nftType[order.nftToken] == 1){
            IERC721(order.nftToken).safeTransferFrom(address(this), _msgSender(), order.tokenId);
        }else {
            IERC1155(order.nftToken).safeTransferFrom(address(this), _msgSender(), order.tokenId, order.amount, "");
        }

        emit TakeOffSale(order.seller, order.orderId, block.timestamp);

    }

    function updatePrice(uint256 _orderId, address _payToken, uint256 _price) public nonReentrant{
        require(orderIdExist[_orderId] , "updatePrice: orderId is not exist");
        orderInfo memory order = orderIdInfo[_orderId];
        require(order.seller == _msgSender() , "updatePrice: sender is not seller");
        require(_payToken == address(0) || TokenDetector.isERC20(_payToken), "updatePrice: invalid payToken address");

        orderIdInfo[_orderId].payToken = _payToken;
        orderIdInfo[_orderId].price = _price;
        
        emit UpdatePrice(order.seller, order.orderId, order.payToken, order.price, block.timestamp);

    }

    function buy(uint256 _orderId) public payable  nonReentrant{
        require(orderIdExist[_orderId] , "buy: orderId is not exist");
        orderInfo storage order = orderIdInfo[_orderId];
        require(order.seller != _msgSender() , "buy: sender is seller");

        uint256 f = order.price.mul(fee).div(10000);
        uint256 income = order.price.sub(f);

        if (order.payToken == address(0)) {
            // require(msg.value == order.price, "buy: abnormal price");
            Address.sendValue(payable(order.seller), income);
            Address.sendValue(payable(socialVault), f);
        } else {
            IERC20(order.payToken).transferFrom(msg.sender, order.seller, income);
            IERC20(order.payToken).transferFrom(msg.sender, socialVault, f);
        }

        if(nftType[order.nftToken] == 1){
            IERC721(order.nftToken).safeTransferFrom(address(this), _msgSender(), order.tokenId);
        }else {
            IERC1155(order.nftToken).safeTransferFrom(address(this), _msgSender(), order.tokenId, order.amount, "");
        }

        order.status = 2;
        order.buyer = msg.sender;
        order.updateTime = block.timestamp;

        deleteOrder(order);

        emit Buy(_msgSender(), order.orderId, block.timestamp);

    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        public 
        override
        returns(bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        public
        override
        returns(bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        public
        override
        returns(bytes4)
    {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IERC1155Receiver).interfaceId || 
            interfaceId == type(IERC721Receiver).interfaceId || 
            super.supportsInterface(interfaceId);
    }

    function getOrderList(address _nftToken, uint256 page, uint256 pageLimit) public view returns (orderInfo[] memory){

        uint256 totalCount = orderIdList[_nftToken].length;
        
        if (pageLimit == 0 || page == 0 || totalCount == 0) {
            return new orderInfo[](0);
        }

        uint256 start = (page - 1) * pageLimit;
        uint256 end = start + pageLimit;
        if (end > totalCount) {
            end = totalCount;
        }

        orderInfo[] memory orders = new orderInfo[](end - start);

        for (uint256 i = start; i < end; i++) {
            uint256 orderId = orderIdList[_nftToken][i];
            orders[i - start] = orderIdInfo[orderId];
        }

        return orders;

    }

    function getOrderListByTokenId(address _nftToken, uint256 _tokenId, uint256 page, uint256 pageLimit) public view returns (orderInfo[] memory){

        uint256 totalCount = orderIdSearch[_nftToken][_tokenId].length;
        
        if (pageLimit == 0 || page == 0 || totalCount == 0) {
            return new orderInfo[](0);
        }

        uint256 start = (page - 1) * pageLimit;
        uint256 end = start + pageLimit;
        if (end > totalCount) {
            end = totalCount;
        }

        orderInfo[] memory orders = new orderInfo[](end - start);

        for (uint256 i = start; i < end; i++) {
            uint256 orderId = orderIdSearch[_nftToken][_tokenId][i];
            orders[i - start] = orderIdInfo[orderId];
        }

        return orders;

    }

    function getUserOrder(address _user, uint256 page, uint256 pageLimit) public view returns (orderInfo[] memory){

        uint256 totalCount = userOrder[_user].length;
        
        if (pageLimit == 0 || page == 0 || totalCount == 0) {
            return new orderInfo[](0);
        }

        uint256 start = (page - 1) * pageLimit;
        uint256 end = start + pageLimit;
        if (end > totalCount) {
            end = totalCount;
        }

        orderInfo[] memory orders = new orderInfo[](end - start);

        for (uint256 i = start; i < end; i++) {
            uint256 orderId = userOrder[_user][i];
            orders[i - start] = orderIdInfo[orderId];
        }

        return orders;

    }


}