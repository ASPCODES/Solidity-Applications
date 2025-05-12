// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ECDSA.sol";

contract ReentrancyGuard {
    bool private locked;

    modifier guard() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }
}

contract UniDirectionalPaymentChannel is ReentrancyGuard {
    using ECDSA for bytes32;

    address public sender;
    address public receiver;
    uint256 private constant DURATION = 7 * 24 * 60 * 60; // 7 days
    uint256 public expiresAT;
    bool public isClosed = false;

    // Event Logs (for transparency and frontend integration)
    event ChannelClosed(uint256 amount, address receiver);
    event ChannelCancelled(address sender);

    constructor(address payable _receiver) payable {
        require(_receiver != address(0), "Receiver cannot be zero address");
        sender = payable(msg.sender);
        receiver = _receiver;
        expiresAT = block.timestamp + DURATION;
    }

    function _getHash(uint256 _amount) private view returns (bytes32) {
        // NOTE: sign with address of this contract to protect against
        // replay attack on other contracts
        return keccak256(abi.encodePacked(address(this), _amount));
    }

    function _getEthSignedHash(uint256 _amount) public view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(_getHash(_amount));
    }

    function getEthSignedHash(uint256 _amount) private view returns (bytes32) {
        return _getEthSignedHash(_amount);
    }

    function _verify(
        uint256 _amount,
        bytes memory _signature
    ) private view returns (bool) {
        return _getEthSignedHash(_amount).recover(_signature) == sender;
    }

    function verify(
        uint256 _amount,
        bytes memory _signature
    ) external view returns (bool) {
        return _verify(_amount, _signature);
    }

    // selfdestruct deprecated so instead use this code

    function close(uint256 _amount, bytes memory _signature) external guard {
        require(!isClosed, "Channel already closed");
        require(msg.sender == receiver, "!receiver");
        require(_verify(_amount, _signature), "invalid signature");

        isClosed = true;

        (bool sent, ) = receiver.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        // Transfer any remaining funds to sender
        uint256 remaining = address(this).balance;
        if (remaining > 0) {
            (bool refund, ) = sender.call{value: remaining}("");
            require(refund, "Refund failed");
        }
    }

    function cancel() external {
        require(!isClosed, "Channel already closed");
        require(msg.sender == sender, "!sender");
        require(block.timestamp >= expiresAT, "!expired");

        isClosed = true;

        (bool refund, ) = sender.call{value: address(this).balance}("");
        require(refund, "Refund failed");
    }
}
