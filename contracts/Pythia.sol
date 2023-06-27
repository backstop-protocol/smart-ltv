// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Pythia {

    struct Data {
        uint value;
        uint lastUpdate;
    }

    mapping(address => mapping(address => mapping(bytes32 => Data))) data;


    function set(address asset, bytes32 key, uint value, uint updateTime) public {
        data[msg.sender][asset][key] = Data(value, updateTime);
    }

    function multiSet(address[] calldata assets, bytes32[] calldata keys, uint[] calldata values, uint[] calldata updateTimes) external {
        require(assets.length == keys.length, "invalid input length");

        for(uint i = 0 ; i < assets.length; i++) {
            set(assets[i], keys[i], values[i], updateTimes[i]);
        }
    }

    function get(address relayer, address asset, bytes32 key) public view returns (Data memory){
        return data[relayer][asset][key];
    }

    function multiGet(address[] calldata relayers, address[] calldata assets, bytes32[] calldata keys) external view returns(Data[] memory results) {
        require(keys.length == relayers.length, "invalid input length");
        require(assets.length == relayers.length, "invalid input length");

        results = new Data[](keys.length);
        for(uint i = 0 ; i < results.length ; i++) {
            results[i] = get(assets[i], relayers[i], keys[i]);
        }
    }
}