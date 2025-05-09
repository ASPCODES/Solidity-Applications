// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    function getAddressSlot(
        bytes32 slot
    ) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// Transparent upgradeable proxy pattern

// Logic Contracts (CounterV1, CounterV2) – Business logic
contract CounterV1 {
    uint256 public count;

    function increment() external {
        count += 1;
    }
}

contract CounterV2 {
    uint256 public count;

    function increment() external {
        count += 1;
    }

    function decrement() external {
        count -= 1;
    }
}

// Problem with BuggyProxy:

// 1. Storage Collision:
// When delegatecall happens, msg.sender, msg.value, and storage layout proxy ke use hote hain.

// Now think of it as, CounterV1 and CounterV2 both first variable count at storage slot is 0.
// But in BuggyProxy, slot 0 is implementation whereas, slot 1 is admin.

// ⛔ Matlab jab logic contract count += 1 karega, wo actually implementation ko overwrite karega! Pure disaster in real use.

// No Safety:

// No checks for contract existence in upgradeTo.
// No storage slot abstraction (like EIP-1967).
// delegatecall(msg.data) blindly call kar raha hai.

contract BuggyProxy {
    address public implementation;
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    function _delegate() private {
        (bool ok, ) = implementation.delegatecall(msg.data);
        require(ok, "Delegatecall failed");
    }

    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    function upgradeTo(address _implementation) external {
        require(msg.sender == admin, "Not admin");
        implementation = _implementation;
    }
}

// EIP-1967 Constants
bytes32 constant IMPLEMENTATION_SLOT = bytes32(
    uint256(keccak256("eip1967.proxy.implementation")) - 1
);
bytes32 constant ADMIN_SLOT = bytes32(
    uint256(keccak256("eip1967.proxy.admin")) - 1
);

contract Proxy {
    constructor(address _implementation, address _admin) {
        require(_implementation.code.length > 0, "Invalid implementation");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = _admin;
    }

    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }

    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    function _setAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "Zero admin");
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address newImpl) internal {
        require(newImpl.code.length > 0, "Not a contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImpl;
    }

    // Admin Interface //
    function changeAdmin(address newAdmin) external ifAdmin {
        _setAdmin(newAdmin);
    }

    function upgradeTo(address newImplementation) external ifAdmin {
        _setImplementation(newImplementation);
    }

    function admin() external ifAdmin returns (address) {
        return _getAdmin();
    }

    function implementation() external ifAdmin returns (address) {
        return _getImplementation();
    }

    // User Interface //
    function _delegate(address _implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.

            // calldatacopy(t, f, s) - copy s bytes from calldata at position f to mem at position t
            // calldatasize() - size of call data in bytes
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.

            // delegatecall(g, a, in, insize, out, outsize) -
            // - call contract at address a
            // - with input mem[in…(in+insize))
            // - providing g gas
            // - and output area mem[out…(out+outsize))
            // - returning 0 on error (eg. out of gas) and 1 on success
            let result := delegatecall(
                gas(),
                _implementation,
                0,
                calldatasize(),
                0,
                0
            )
            // Copy the returned data.
            // returndatacopy(t, f, s) - copy s bytes from return data at position f to mem at position t
            // returndatasize() - size of the last return data
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                // revert(p, s) - end execution, revert state changes, return data mem[p…(p+s))
                revert(0, returndatasize())
            }
            default {
                // return(p, s) - end execution, return data mem[p…(p+s))
                return(0, returndatasize())
            }
        }
    }

    function _fallback() internal {
        _delegate(_getImplementation());
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}

contract ProxyAdmin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function getProxyAdmin(address proxy) external view returns (address) {
        (bool ok, bytes memory res) = proxy.staticcall(
            abi.encodeWithSignature("admin()")
        );
        require(ok, "call failed");
        return abi.decode(res, (address));
    }

    function getProxyImplementation(
        address proxy
    ) external view returns (address) {
        (bool ok, bytes memory res) = proxy.staticcall(
            abi.encodeWithSignature("implementation()")
        );
        require(ok, "call failed");
        return abi.decode(res, (address));
    }

    function changeProxyAdmin(
        address proxy,
        address newAdmin
    ) external onlyOwner {
        (bool ok, ) = proxy.call(
            abi.encodeWithSignature("changeAdmin(address)", newAdmin)
        );
        require(ok, "Admin change failed");
    }

    function upgrade(address proxy, address implementation) external onlyOwner {
        (bool ok, ) = proxy.call(
            abi.encodeWithSignature("upgradeTo(address)", implementation)
        );
        require(ok, "Upgrade failed");
    }
}

contract TestSlot {
    bytes32 public constant slot = keccak256("TEST_SLOT");

    function getSlot() external view returns (address) {
        return StorageSlot.getAddressSlot(slot).value;
    }

    function writeSlot(address _addr) external {
        StorageSlot.getAddressSlot(slot).value = _addr;
    }
}
