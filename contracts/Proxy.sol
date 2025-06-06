// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Deploy any contract by calling Proxy.deploy(bytes memory _code)

contract Proxy {
    event Deploy(address);

    receive() external payable {}

    function deploy(
        bytes memory _code
    ) external payable returns (address addr) {
        assembly {
            // create(v, p, n)
            // v = amount of ETH to send
            // p = pointer in memory to start of code
            // n = size of code
            addr := create(callvalue(), add(_code, 0x20), mload(_code))
        }
        // return address 0 on error
        require(addr != address(0), "create failed");

        // emit event with address of deployed contract
        emit Deploy(addr);
    }

    function execute(address _target, bytes memory _data) external payable {
        // call the target contract with the provided data
        (bool success, ) = _target.call{value: msg.value}(_data);
        require(success, "call failed");
    }
}

contract TestContract1 {
    address public owner = msg.sender;

    function setOwner(address _owner) public {
        require(msg.sender == owner, "not owner");
        owner = _owner;
    }
}

contract TestContract2 {
    address public owner = msg.sender;
    uint256 public value = msg.value;
    uint256 public x;
    uint256 public y;

    constructor(uint256 _x, uint256 _y) payable {
        x = _x;
        y = _y;
    }
}

contract Helper {
    function getByteCode1() external pure returns (bytes memory) {
        bytes memory bytecode = type(TestContract1).creationCode;
        return bytecode;
    }

    function getByteCode2(
        uint256 _x,
        uint256 _y
    ) external pure returns (bytes memory) {
        bytes memory bytecode = type(TestContract2).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_x, _y));
    }

    function getCallData(address _owner) external pure returns (bytes memory) {
        return abi.encodeWithSignature("setOwner(address)", _owner);
    }
}
