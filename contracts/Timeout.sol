// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";



contract Timeout is KeeperCompatibleInterface {

    constructor() {

    }

    using Counters for Counters.Counter;

    enum Status{ QUEUED, RUNNING, COMPLETED }

    struct Function {
        address contractAddress;
        string signature;
        bytes parameters;
        uint subscribedAt;
        uint interval;
        uint value;
        Status status;
    }

    event FunctionEnqueued(uint id, uint interval);
    event FunctionExecuted(uint id);

    Counters.Counter private _id;
    uint costToEnqueue = 0.0000001 ether;
    mapping( uint => Function ) public functions;
    uint[] public queuedFunctions;

    function getTimedOutQueuedFunctions() public view returns(uint[] memory){
        uint[] memory p_queuedFunctions = queuedFunctions;
        uint[] memory timedoutFunctions = new uint[](p_queuedFunctions.length);
        uint256 count = 0;
        Function memory target;
        for(uint256 idx = 0; idx < p_queuedFunctions.length; idx++) {
            target = functions[p_queuedFunctions[idx]];
            if((block.timestamp - target.subscribedAt) > target.interval && target.status == Status.QUEUED) {
                timedoutFunctions[count] = p_queuedFunctions[idx];
                count++;
            }
        }
        if (count != timedoutFunctions.length) {
            assembly {
                mstore(timedoutFunctions, count)
            }
        }
        return timedoutFunctions;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData ) {
        uint[] memory timedoutFunctions = getTimedOutQueuedFunctions();
        upkeepNeeded = timedoutFunctions.length > 0;
        performData = abi.encode(timedoutFunctions);
    }

    function performUpkeep(bytes calldata performData) external override {
        uint[] memory timedoutFunctions = abi.decode(performData, (uint[]));
        call(timedoutFunctions);
    }

    function enqueue(address contractAddress, string calldata signature, bytes calldata parameters, uint interval) public payable returns(uint){
        console.log("enqueue");
        require(msg.value >= costToEnqueue, "Not enough funds sent");
        _id.increment();
        functions[_id.current()] = Function({
            contractAddress: contractAddress,
            signature: signature,
            parameters: parameters,
            subscribedAt: block.timestamp,
            interval: interval,
            value: msg.value,
            status: Status.QUEUED
        });
        queuedFunctions.push(_id.current());
        emit FunctionEnqueued(_id.current(), interval);
        console.log("enqueued");
        return _id.current();
    }

    function call(uint[] memory timedoutFunctions) private {
    
        for(uint idx = 0; idx < timedoutFunctions.length; idx++) {
            Function memory f = functions[timedoutFunctions[idx]];
            f.status = Status.RUNNING;
            functions[timedoutFunctions[idx]] = f;
            console.log(f.signature);
            (bool success, bytes memory data) = address(f.contractAddress).call( 
                abi.encodeWithSelector(
                    bytes4(
                        keccak256(bytes(f.signature))
                    ),
                    f.parameters
                )
            );
            console.logBool(success);
            console.logBytes(data);
            f.status = Status.COMPLETED;
            functions[timedoutFunctions[idx]] = f;
            emit FunctionExecuted(timedoutFunctions[idx]);
        }
    }


    function currentId() public view returns(uint){
        return _id.current();
    }
}



