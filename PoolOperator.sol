pragma solidity ^0.5.5;

interface IOperator {

    function setPoolTime(uint256 _start, uint256 _end) external;

    function starttime() external view returns (uint256);

    function periodFinish() external view returns (uint256);
}

contract PoolOperator {
    IOperator[] public pools;

    address public owner = 0x480221ee9C04c8a28619cF4F40477B23974D40de;
    address robot = 0x37f618F2b4Fde18aa48E2ADf316426EeDff00A20;

    modifier checkOperator() {
        require(msg.sender == owner || msg.sender == robot, 'not operator');
        _;
    }

    function setPools(IOperator[]memory _pools) public checkOperator {
        for (uint256 i = 0; i < _pools.length; i++) {
            pools.push(_pools[i]);
        }
    }

    function addPool(IOperator _pool) public checkOperator {
        pools.push(_pool);
    }

    function setAll(uint256 _start, uint256 _end) public checkOperator {

        for (uint256 i = 0; i < pools.length; i++) {
            pools[i].setPoolTime(_start, _end);
        }
    }

    function setTime(address _pool, uint256 _start, uint256 _end) public checkOperator {
        for (uint256 i = 0; i < pools.length; i++) {
            if (address(pools[i]) == _pool) {
                pools[i].setPoolTime(_start,_end);
                break;
            }
        }
    }

    function getPools() public view returns (address[]memory addrArr, uint256[] memory startArr, uint256[] memory endArr){
        if (pools.length > 0) {
            uint256 len = pools.length;
            addrArr = new address[](len);
            startArr = new uint256[](len);
            endArr = new uint256[](len);
            for (uint256 i = 0; i < len; i++) {
                addrArr[i] = address(pools[i]);
                startArr[i] = pools[i].starttime();
                endArr[i] = pools[i].periodFinish();

            }
        }

    }
}
