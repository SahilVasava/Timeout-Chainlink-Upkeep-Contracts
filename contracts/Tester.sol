// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
import "hardhat/console.sol";
interface ITimeout {
        function enqueue(address contractAddress, string calldata signature, bytes calldata parameters, uint interval) external payable returns(uint);
}

contract Tester {
    uint public counter;

    constructor() {

    }

    function register(address timeout) public payable returns(uint) {
        ITimeout mTimeout = ITimeout(timeout);
        uint id = mTimeout.enqueue{ value: msg.value }(address(this), "callback(bytes)", abi.encode(0), 30);
        return id;
    }

    function callback(bytes memory hello) external {
        console.logBytes(hello);
        counter++;
        console.log("Called!");
    }
}
