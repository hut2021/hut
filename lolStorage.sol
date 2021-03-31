pragma solidity ^0.5.5;
pragma experimental ABIEncoderV2;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function burn(uint256 amount) external returns (bool success);

    function burnFrom(address account, uint256 amount) external returns (bool success);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

library OrderIdMap {


    struct Map {
        uint256[] _entries;
        mapping(uint256 => uint8) _indexes;
    }

    function length(Map storage _map) internal view returns (uint256) {
        return _map._entries.length;
    }

    function lengthMemory(Map memory _map) internal pure returns (uint256) {
        return _map._entries.length;
    }

    function contains(Map storage _map, uint256 key) internal view returns (bool) {
        return _map._indexes[key] != 0;
    }

    function set(Map storage _map, uint256 key) internal returns (bool) {
        if (!contains(_map, key)) {
            _map._entries.push(key);
            _map._indexes[key] = uint8(_map._entries.length);
            return true;
        } else {
            return false;
        }
    }

    function remove(Map storage _map, uint256 value) internal returns (bool) {
        uint8 valueIndex = _map._indexes[value];
        if (valueIndex != 0) {// Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint8 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = _map._entries.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            uint256 lastvalue = _map._entries[lastIndex];

            // Move the last value to the index where the value to delete is
            _map._entries[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            _map._indexes[lastvalue] = toDeleteIndex + 1;
            // All indexes are 1-based

            // Delete the slot where the moved value was stored
            _map._entries.pop();

            // Delete the index for the deleted slot
            delete _map._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    function getArr(Map storage _map) internal view returns (uint256[]memory){
        return _map._entries;
    }

    function getArrMemory(Map memory _map) internal pure returns (uint256[]memory){
        return _map._entries;
    }
    //    function get(Map storage _map,)


}


contract lolStorage {

    function safeBurn(address token, uint256 value) internal {
        // bytes4 id = bytes4(keccak256("burn(uint256)"));
        // bool success = token.call(id, to, value);
        // require(success, 'TransferHelper: TRANSFER_FAILED');
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x42966c68, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }
    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4 id = bytes4(keccak256("transfer(address,uint256)"));
        // bool success = token.call(id, to, value);
        // require(success, 'TransferHelper: TRANSFER_FAILED');
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

        // bytes4 id = bytes4(keccak256("transferFrom(address,address,uint256)"));
        // bool success = token.call(id, from, to, value);
        // require(success, 'TransferHelper: TRANSFER_FROM_FAILED');
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    using OrderIdMap for OrderIdMap.Map;
    using SafeMath for uint256;
    struct User {
        address referrerAddr;
        uint256 inputAmount;
        uint256 staticBonus;
        uint256 dyBonus;
        uint256 poolBonus;
        uint256 heroBonus;
        uint256 lastCheckTime;
        uint256 unfreezeTime;
        uint256 historyStaticBonus;
        uint256 historyDyBonus;
        uint256 historyPoolBonus;
        uint256 historyHeroBonus;
        uint256 valueA;
        uint256 valueB;
        uint256 valueC;
        uint256 valueD;
        uint256 valueE;
        uint8 valid;
        uint8 staking;
        Order[] orderArr;
        OrderIdMap.Map validOrders;

    }

    struct Order {
        uint256 orderId;
        uint256 amount;
        uint256 investTime;
        uint8 valid;
    }
    //

    uint8 constant TYPE_VALID = 1;
    uint8 constant TYPE_INVALID = 0;
    uint8 MAX_VALID_ORDER_COUNT = 20;

    uint256 RETURN_TYPE_BUY = 1003;
    uint256 RETURN_TYPE_SELL = 1004;
    uint256 ONE_DAY = 1 days;
    uint256 OUT_DAY = 7 days;

    //
    address tokenAddr = 0xe620112303A426970501A02aeBD45b791960AFb7;
    uint256 tokenDecimal = 8;

    address USDAddr = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    address rootAccount = 0x71f1d1A049aAa4AFF7b609219f7cad58d9ee09C6;
    address public owner = 0x3b48bE0D2ab4c6f1137a635c3d0F5DA5B12DE530;
    address robot = 0x37f618F2b4Fde18aa48E2ADf316426EeDff00A20;
    address feeAddr = 0xbe5d6767AF835CF5EE7820528bd7C976bEF1E60D;
    address nftTokenAddr = 0xAFEbE80539da79cAAF29a4f709B28036b2Af2bA7;

    uint256 exitFeePercent = 2;
    uint256 exitUserPercent = 98;
    uint256 percent100 = 100;
    uint256 daily_percent = 25;
    uint256 percent10000 = 10000;
    //

    //
    uint256 MIN_TOKEN = 100 * 10 ** tokenDecimal;
    uint256 ONE_TOKEN = 1 * 10 ** tokenDecimal;
    uint256 TWO_TOKEN = 2 * 10 ** tokenDecimal;
    uint256 THREE_TOKEN = 3 * 10 ** tokenDecimal;
    uint256 MAX_TOKEN = 50000 * 10 ** tokenDecimal;

    uint256 INTERNAL_TRANSFER_FEE_TOKEN = ONE_TOKEN * 1 / 100;
    //
    mapping(uint256 => address) nftTokenMap;
    mapping(uint256 => uint256) nftPriceMap;
    //
    mapping(address => User) userMap;
    address[]userArr;

    //sys
    uint256 totalAmount;
    uint256 feeReward;
    //
    uint256 globalA;
    uint256 globalB;
    uint256 globalC;
    uint256 globalD;
    uint256 globalE;

    constructor () public {
        User storage user = userMap[rootAccount];
        user.valid = 1;
    }
}
