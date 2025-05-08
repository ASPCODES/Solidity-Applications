""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
 * @title Factory Contract
 * @dev This contract demonstrates the deployment of a minimal EVM bytecode contract
 *      that always returns the value 255 when called.
 */
contract Factory {
    // Event emitted after successful contract deployment
    event Log(address addr);

    /*
     * @dev Deploys a minimal EVM bytecode contract that returns 255.
     *      The bytecode is constructed to execute a simple return operation.
     *
     * Bytecode Breakdown:
     * - 60ff: PUSH1 0xff (Pushes 255 onto the stack)
     * - 6000: PUSH1 0x00 (Pushes 0 onto the stack, the memory position)
     * - 52: MSTORE (Stores 255 at memory position 0x00)
     * - 6020: PUSH1 0x20 (Pushes 32 onto the stack, representing the size of the data to return)
     * - 6000: PUSH1 0x00 (Pushes 0 onto the stack, the memory position to return from)
     * - f3: RETURN (Returns 32 bytes from memory starting at position 0x00)
     */
    function deploy() external {
        // Minimal bytecode that always returns 255
        bytes memory bytecode = hex"6960ff60005260206000f3600052600a6016f3";
        address addr;

        /*
         * Inline assembly is used here to deploy the bytecode:
         * - create(value, offset, size): creates a new contract
         *   @param value: Amount of Ether to send (0 in this case)
         *   @param offset: Pointer to the bytecode
         *   @param size: Size of the bytecode
         */
        assembly {
            addr := create(0, add(bytecode, 0x20), 0x13)
        }

        // Ensure the address is not zero (deployment succeeded)
        require(addr != address(0), "Deployment failed");

        // Emit the address of the newly deployed contract
        emit Log(addr);
    }
}

/*
 * @title IContract Interface
 * @dev This is an interface for the minimal contract deployed by Factory.
 *      It allows reading the value returned by the contract.
 */
interface IContract {
    function getValue() external view returns (uint256);
}

/*
 * Bytecode Analysis:
 * ------------------
 * Run-time Bytecode:
 * 60ff60005260206000f3
 * - PUSH1 0xff           -> Pushes 255 onto the stack
 * - PUSH1 0x00           -> Pushes memory position 0 onto the stack
 * - MSTORE               -> Stores 255 at memory position 0
 * - PUSH1 0x20           -> Pushes 32 (byte length) onto the stack
 * - PUSH1 0x00           -> Pushes memory position 0 onto the stack
 * - RETURN               -> Returns 32 bytes from memory (which is the value 255)
 *
 * Creation Bytecode:
 * 6960ff60005260206000f3600052600a6016f3
 * - PUSH10 0x60ff60005260206000f3 -> Pushes runtime bytecode to the stack
 * - PUSH1 0x00                    -> Sets memory start position to 0
 * - MSTORE                        -> Stores the runtime bytecode at position 0
 * - PUSH1 0x0a                    -> Specifies the size of the runtime code (10 bytes)
 * - PUSH1 0x16                    -> Specifies the start position of the runtime code
 * - RETURN                        -> Returns the runtime code from memory
 */
""
