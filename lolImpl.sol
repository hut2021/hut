pragma solidity ^0.5.5;
pragma experimental ABIEncoderV2;

import "./lolStorage.sol";

interface lolInterface {
    function stake(address referrer, uint256 amount) external;
    function withdrawStake(uint256 stakeId) external;

    function withdrawStaticBonus() external;
    function withdrawDyBonus() external;
    function withdrawPoolBonus() external;
    function withdrawHeroBonus() external;

    function openBox(uint256[]calldata boxIdArr) external;
    function synthesisProps(uint256 propsType, uint256 propsIdA, uint256 propsIdB) external;
    function synthesisHero(uint256 propsType, uint256 propsIdA, uint256 propsIdB) external;
    function transferProps(address to, uint256 propsType, uint256 propsId) external;
    function wearProps(uint256 heroId, uint256 propsType, uint256 propsId) external;
    function upgradeHero(uint256 heroId, uint256 propsId) external;

    function sell(uint256 propsType, uint256 propsId, uint256 orderAmount) external;
    function cancelOrder(uint256 orderId) external;
    function buy(uint256 orderId, uint256 orderAmount) external;

    function distribute(address[] calldata addrArr, uint256[]calldata dyArr, uint256[]calldata poolArr, uint256[]calldata heroArr) external;
    function returnAmount(address to, uint256 amount, uint256 returnType, uint256 orderId) external;

    function sellHero(address from, uint256 tokenId, uint256 orderAmount) external;
    function cancelHeroOrder(uint256 tokenId) external;
    function buyHero(uint256 tokenId) external;

    function getSysInfo() external view returns (uint256, uint256, uint256);
    function getUserInfo(address addr) external view returns (uint8, address, uint256, uint256, uint256, uint256);
    function getBonus(address addr) external view returns (uint256, uint256, uint256, uint256);
    function getHistoryBonus(address addr) external view returns (uint256, uint256, uint256, uint256);
    function getUserValidOrders(address addr) external view returns (lolStorage.Order[]memory);
    function getUserAllOrders(address addr, uint256 startIndex, uint256 len) external view returns (lolStorage.Order[]memory);
    function getUserValidOrdersArr(address addr) external view returns (uint256[]memory, uint256[]memory, uint256[]memory, uint8[]memory);
    function getUserAllOrdersArr(address addr, uint256 startIndex, uint256 len) external view returns (uint256[]memory, uint256[]memory, uint256[]memory, uint8[]memory);

    event Stake(address indexed from, address indexed referrer, uint256 amount, uint256 stakeId, uint256 stakeTime);
    event WithdrawStake(address indexed from, uint256 amount, uint256 stakeId);
    event NewUser(address indexed from, address indexed referrer, uint256 amount, uint256 stakeTime);
    event WithdrawStaticBonus(address indexed from, uint256 amount);
    event WithdrawDyBonus(address indexed from, uint256 amount);
    event WithdrawPoolBonus(address indexed from, uint256 amount);
    event WithdrawHeroBonus(address indexed from, uint256 amount);
    event Sell(address indexed from, uint256 propsType, uint256 propsId, uint256 orderAmount);
    event CancelOrder(address indexed from, uint256 orderId);
    event Buy(address indexed from, uint256 orderId, uint256 orderAmount);
    event ReturnAmount(address indexed to, uint256 amount, uint256 returnType, uint256 orderId);
    event OpenBox(address indexed from, uint256[] boxIdArr);
    event SynthesisProps(address indexed from, uint256 propsType, uint256 propsIdA, uint256 propsIdB);
    event SynthesisHero(address indexed from, uint256 propsType, uint256 propsIdA, uint256 propsIdB);
    event TransferProps(address indexed from, address indexed to, uint256 propsType, uint256 propsId);
    event WearProps(address indexed from, uint256 heroId, uint256 propsType, uint256 propsId);
    event UpgradeHero(address indexed from, uint256 heroId, uint256 propsId);
    event SellHero(address indexed from, uint256 tokenId, uint256 orderAmount);
    event CancelHeroOrder(address indexed from, uint256 tokenId);
    event BuyHero(address indexed preOwner, address indexed curOwner, uint256 tokenId, uint256 orderAmount);

}
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}
interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns (bytes4);
}

contract lolImpl is lolStorage, lolInterface, ERC721TokenReceiver {


    modifier onlyOwner(){
        require(msg.sender == owner || msg.sender == robot, "Ownable: caller is not the owner");
        _;
    }

    modifier operatingCost(uint256 feeAmount){
        safeTransferFrom(tokenAddr, msg.sender, address(this), feeAmount);
        _;
    }

    function _transferFee(uint256 feeAmount) internal {
        safeTransfer(tokenAddr, feeAddr, feeAmount.mul(20).div(100));
        safeBurn(tokenAddr, feeAmount.mul(30).div(100));
        feeReward = feeReward.add(feeAmount.mul(50).div(100));
    }

    function _checkUpUser(address _upAddr) internal view returns (bool){
        return (userMap[_upAddr].valid == 1);
    }
    //======================================
    function stake(address referrer, uint256 amount) public {
        require(msg.sender != rootAccount, "not allowed");
        require(amount >= MIN_TOKEN, "min 100");
        require(amount <= MAX_TOKEN, "max 50000");
        require(amount.mod(MIN_TOKEN) == 0, "multi 100");

        User storage user = userMap[msg.sender];
        require(user.validOrders.length() <= MAX_VALID_ORDER_COUNT, "max");
        if (user.valid == 0) {
            require(_checkUpUser(referrer), "invalid referrer");
            user.valid = TYPE_VALID;
            user.referrerAddr = referrer;
            user.inputAmount = amount;
            user.lastCheckTime = now;
            user.unfreezeTime = now.add(OUT_DAY);
            emit NewUser(msg.sender, referrer, amount, now);
            //
            userArr.push(msg.sender);
            userMap[msg.sender] = user;
        } else {
            user.inputAmount = user.inputAmount.add(amount);
        }

        safeTransferFrom(tokenAddr, msg.sender, address(this), amount);

        user.staking = TYPE_VALID;
        //
        totalAmount = totalAmount.add(amount);
        //Order
        uint256 orderId = user.orderArr.length;
        Order memory newOrder = Order(orderId, amount, now, TYPE_VALID);
        require(user.validOrders.set(orderId), " set fail");
        user.orderArr.push(newOrder);

        emit Stake(msg.sender, user.referrerAddr, amount, orderId, now);
    }

    function withdrawStake(uint256 stakeId) public {
        User storage user = userMap[msg.sender];
        require(user.valid == TYPE_VALID, "invalid address");
        require(user.validOrders.contains(stakeId), "invalid id");
        Order storage order = user.orderArr[stakeId];
        require(order.valid == TYPE_VALID, "invalid status");
        require(user.unfreezeTime <= now, "less than 7 days, not allowed");

        {
            uint256 bonus = getOrderBonus(msg.sender, stakeId);
            if (bonus > 0) {
                safeTransfer(tokenAddr, msg.sender, bonus);
                user.historyStaticBonus = user.historyStaticBonus.add(bonus);
                emit WithdrawStaticBonus(msg.sender, bonus);
            }
        }
        order.valid = TYPE_INVALID;
        //
        user.inputAmount = user.inputAmount.sub(order.amount);
        totalAmount = totalAmount.sub(order.amount);
        require(user.validOrders.remove(stakeId), "op err");
        uint256 len = user.validOrders.length();
        if (len == 0) {
            user.staking = TYPE_INVALID;
        }
        //
        safeTransfer(tokenAddr, msg.sender, order.amount);
        emit WithdrawStake(msg.sender, order.amount, stakeId);

    }
    //======================================
    function getOrderBonus(address addr, uint256 stakeId) public view returns (uint256){
        User memory user = userMap[addr];
        require(stakeId < user.orderArr.length, "invalid id");
        Order memory order = user.orderArr[stakeId];
        if (order.valid == TYPE_INVALID) {
            return 0;
        }

        uint256 orderCheckTime = user.lastCheckTime;
        if(orderCheckTime < order.investTime){
            orderCheckTime = order.investTime;
        }
        uint256 diffTime = now.sub(orderCheckTime);
        uint256 bonus = order.amount.mul(daily_percent).mul(diffTime).div(ONE_DAY).div(percent10000);
        return bonus;
    }

    function withdrawStaticBonus() public {
        User storage user = userMap[msg.sender];
        require(user.staking == TYPE_VALID, "invalid status");
        uint256 len = user.validOrders.length();
        require(len > 0, "len 0");
        uint256[]memory indexArr = user.validOrders.getArr();
        uint256 bonus;
        for (uint i = 0; i < len; i++) {
            bonus = bonus.add(getOrderBonus(msg.sender, indexArr[i]));
        }
        require(bonus > 0, "not enough");
        safeTransfer(tokenAddr, msg.sender, bonus);
        user.historyStaticBonus = user.historyStaticBonus.add(bonus);
        emit WithdrawStaticBonus(msg.sender, bonus);

        user.lastCheckTime = now;
    }

    function withdrawDyBonus() public {
        User storage user = userMap[msg.sender];
        require(user.dyBonus > 0, "not enough");
        safeTransfer(tokenAddr, msg.sender, user.dyBonus);
        user.historyDyBonus = user.historyDyBonus.add(user.dyBonus);
        user.dyBonus = 0;
        emit WithdrawDyBonus(msg.sender, user.dyBonus);
    }

    function withdrawPoolBonus() public {
        User storage user = userMap[msg.sender];
        require(user.poolBonus > 0, "not enough");
        safeTransfer(tokenAddr, msg.sender, user.poolBonus);
        user.historyPoolBonus = user.historyPoolBonus.add(user.poolBonus);
        user.poolBonus = 0;
        emit WithdrawPoolBonus(msg.sender, user.poolBonus);
    }

    function withdrawHeroBonus() public {
        User storage user = userMap[msg.sender];
        require(user.heroBonus > 0, "not enough");
        safeTransfer(tokenAddr, msg.sender, user.heroBonus);
        user.historyHeroBonus = user.historyHeroBonus.add(user.heroBonus);
        user.heroBonus = 0;
        emit WithdrawHeroBonus(msg.sender, user.heroBonus);
    }
    //======================================
    function openBox(uint256[]memory boxIdArr) public operatingCost(ONE_TOKEN.mul(boxIdArr.length)) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        require(boxIdArr.length > 0, "len  0");
        _transferFee(ONE_TOKEN.mul(boxIdArr.length));
        emit OpenBox(msg.sender, boxIdArr);
    }

    function synthesisProps(uint256 propsType, uint256 propsIdA, uint256 propsIdB) public operatingCost(THREE_TOKEN) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        _transferFee(THREE_TOKEN);
        emit SynthesisProps(msg.sender, propsType, propsIdA, propsIdB);
    }

    function synthesisHero(uint256 propsType, uint256 propsIdA, uint256 propsIdB) public operatingCost(TWO_TOKEN) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        _transferFee(TWO_TOKEN);
        emit SynthesisHero(msg.sender, propsType, propsIdA, propsIdB);
    }

    function transferProps(address to, uint256 propsType, uint256 propsId) public operatingCost(INTERNAL_TRANSFER_FEE_TOKEN) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        require(userMap[to].valid == TYPE_VALID, "invalid to");
        safeTransfer(tokenAddr, feeAddr, INTERNAL_TRANSFER_FEE_TOKEN);
        emit TransferProps(msg.sender, to, propsType, propsId);
    }

    function wearProps(uint256 heroId, uint256 propsType, uint256 propsId) public operatingCost(ONE_TOKEN) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        _transferFee(ONE_TOKEN);
        emit WearProps(msg.sender, heroId, propsType, propsId);
    }

    function upgradeHero(uint256 heroId, uint256 propsId) public operatingCost(ONE_TOKEN) {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        _transferFee(ONE_TOKEN);
        emit UpgradeHero(msg.sender, heroId, propsId);
    }

    //======================================
    function sell(uint256 propsType, uint256 propsId, uint256 orderAmount) public {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        emit Sell(msg.sender, propsType, propsId, orderAmount);
    }

    function cancelOrder(uint256 orderId) public {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        emit CancelOrder(msg.sender, orderId);
    }

    function buy(uint256 orderId, uint256 orderAmount) public {
        require(userMap[msg.sender].valid == TYPE_VALID, "invalid");
        safeTransferFrom(USDAddr, msg.sender, address(this), orderAmount);
        emit Buy(msg.sender, orderId, orderAmount);
    }


    function getDataMethod(bytes memory _data) public pure returns (bytes4 method){
        require(_data.length >= 4, "len");
        assembly {
            method := mload(add(_data, 32))
        }
    }


    function checkERC721Params(address _from, uint256 _tokenId, bytes memory _data) public pure returns (bool){
        require(_data.length >= 68, "len 68");
        bytes memory abiBytes = abi.encodeWithSelector(bytes4(keccak256("sellHero(address,uint256,uint256)")), _from, _tokenId);
        bytes memory dataSlice = new bytes(68);
        for (uint i = 0; i < 68; i++) {
            dataSlice[i] = _data[i];
        }
        return keccak256(abiBytes) == keccak256(dataSlice);
    }


    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns (bytes4){
        require(checkERC721Params(_from, _tokenId, _data), "illegal calldata");
        (bool success,) = address(this).call(_data);
        require(success, 'CALL_SELL_FAILED');
        return 0x150b7a02;
    }
    function sellHero(address _from, uint256 tokenId, uint256 orderAmount) public {
        require(msg.sender == address(this), "illegal operation");
        require(tx.origin == _from, "illegal operation owner");
        nftTokenMap[tokenId] = _from;
        nftPriceMap[tokenId] = orderAmount;
        emit SellHero(_from, tokenId, orderAmount);
    }
    
    function cancelHeroOrder(uint256 tokenId) public {
        IERC721 token = IERC721(nftTokenAddr);
        require(tx.origin == msg.sender, "illegal sender");
        require(tx.origin == nftTokenMap[tokenId], "illegal operation owner");
        token.safeTransferFrom(address(this), tx.origin, tokenId);
        delete nftTokenMap[tokenId];
        delete nftPriceMap[tokenId];
        emit CancelHeroOrder(tx.origin, tokenId);
    }
    
    function buyHero(uint256 tokenId) public {
        require(tx.origin == msg.sender, "illegal sender");
        require(nftTokenMap[tokenId] != address(0), "not exist");
        address pre = nftTokenMap[tokenId];
        //721
        IERC721 token721 = IERC721(nftTokenAddr);
        token721.safeTransferFrom(address(this), msg.sender, tokenId);
        //u
        uint256 orderAmount = nftPriceMap[tokenId];
        safeTransferFrom(USDAddr, msg.sender, address(this), orderAmount);
        safeTransfer(USDAddr, pre, orderAmount);

        emit BuyHero(pre, msg.sender, tokenId, orderAmount);
        delete nftTokenMap[tokenId];
        delete nftPriceMap[tokenId];

    }

    //======================================
    function distribute(address[] memory addrArr, uint256[]memory dyArr, uint256[]memory poolArr, uint256[]memory heroArr) public onlyOwner {
        uint len = addrArr.length;
        for (uint i = 0; i < len; i++) {
            User storage user = userMap[addrArr[i]];
            if (user.valid == TYPE_VALID) {
                if (dyArr[i] > 0) {
                    user.dyBonus = user.dyBonus.add(dyArr[i]);
                }
                if (poolArr[i] > 0) {
                    user.poolBonus = user.poolBonus.add(poolArr[i]);
                }
                if (heroArr[i] > 0) {
                    user.heroBonus = user.heroBonus.add(heroArr[i]);
                    feeReward = feeReward.sub(heroArr[i]);
                }
            }
        }

    }

    function returnAmount(address to, uint256 amount, uint256 returnType, uint256 orderId) public onlyOwner {
        if (returnType == RETURN_TYPE_BUY) {
            safeTransfer(USDAddr, to, amount);
        } else if (returnType == RETURN_TYPE_SELL) {
            safeTransfer(USDAddr, to, amount);
        } else {
            safeTransfer(tokenAddr, to, amount);
        }

        emit ReturnAmount(to, amount, returnType, orderId);
    }

    //======================================
    function getSysInfo() public view returns (uint256, uint256, uint256){
        return (totalAmount, userArr.length, feeReward);
    }
    function getUserInfo(address addr) public view returns (uint8, address, uint256, uint256, uint256, uint256){
        User memory user = userMap[addr];
        uint256 withdrawed = 0;
        if (user.unfreezeTime != 0 && user.unfreezeTime <= now) {
            withdrawed = 1;
        }
        return (user.valid, user.referrerAddr, user.inputAmount, user.lastCheckTime, user.validOrders.lengthMemory(), withdrawed);
    }
    function getBonus(address addr) public view returns (uint256, uint256, uint256, uint256){
        User memory user = userMap[addr];
        if (user.valid == TYPE_INVALID) {
            return (0, 0, 0, 0);
        }
        uint256 len = user.validOrders.lengthMemory();
        uint256 staticBonus = 0;
        if (len > 0) {
            uint256[]memory orderIndexArr = user.validOrders.getArrMemory();
            for (uint i = 0; i < len; i++) {
                staticBonus = staticBonus.add(getOrderBonus(addr, orderIndexArr[i]));
            }
        }

        return (staticBonus, user.dyBonus, user.poolBonus, user.heroBonus);
    }
    function getHistoryBonus(address addr) public view returns (uint256, uint256, uint256, uint256){
        User memory user = userMap[addr];
        if (user.valid == TYPE_INVALID) {
            return (0, 0, 0, 0);
        }
        return (user.historyStaticBonus, user.historyDyBonus, user.historyPoolBonus, user.historyHeroBonus);
    }

    function getUserValidOrders(address addr) public view returns (lolStorage.Order[]memory result){
        User memory user = userMap[addr];
        if (user.valid == TYPE_VALID) {
            uint256 len = user.validOrders.lengthMemory();
            if (len > 0) {
                result = new lolStorage.Order[](len);
                uint256[]memory orderIndexArr = user.validOrders.getArrMemory();
                for (uint256 i = 0; i < len; i++) {
                    result[i] = user.orderArr[orderIndexArr[i]];
                }
            }
        }
        return result;
    }
    
    function getUserAllOrders(address addr, uint256 startIndex, uint256 len) public view returns (lolStorage.Order[]memory result){
        User memory user = userMap[addr];
        if (user.valid == TYPE_VALID) {
            require(startIndex + len <= user.orderArr.length, "out of bounds");
            result = new lolStorage.Order[](len);
            for (uint256 i = startIndex; i < len; i++) {
                result[i] = user.orderArr[i];
            }
        }
        return result;
    }
    
    function getUserValidOrdersArr(address addr) public view returns (uint256[]memory ids, uint256[]memory amounts, uint256[]memory times, uint8[] memory status){
        User memory user = userMap[addr];
        if (user.valid == TYPE_VALID) {
            uint256 len = user.validOrders.lengthMemory();
            if (len > 0) {
                ids = new uint256[](len);
                amounts = new uint256[](len);
                times = new uint256[](len);
                status = new uint8[](len);
                uint256[]memory orderIndexArr = user.validOrders.getArrMemory();
                for (uint256 i = 0; i < len; i++) {
                    Order memory od = user.orderArr[orderIndexArr[i]];
                    ids[i] = od.orderId;
                    amounts[i] = od.amount;
                    times[i] = od.investTime;
                    status[i] = od.valid;
                }
            }
        }
    }
    
    function getUserAllOrdersArr(address addr, uint256 startIndex, uint256 len) public view returns (uint256[]memory ids, uint256[]memory amounts, uint256[]memory times, uint8[] memory status){
        User memory user = userMap[addr];
        if (user.valid == TYPE_VALID) {
            require(startIndex + len <= user.orderArr.length, "out of bounds");
            ids = new uint256[](len);
            amounts = new uint256[](len);
            times = new uint256[](len);
            status = new uint8[](len);
            for (uint256 i = startIndex; i < len; i++) {
                Order memory od = user.orderArr[i];
                ids[i] = od.orderId;
                amounts[i] = od.amount;
                times[i] = od.investTime;
                status[i] = od.valid;
            }
        }
    }
    
    function setLOLFeeAddr(address _addr) public onlyOwner {
        feeAddr = _addr;
    }
}
