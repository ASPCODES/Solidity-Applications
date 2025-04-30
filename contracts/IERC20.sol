// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/* ERC20 TOKEN (Ethereum Request for Comments) */
/* Topics Include:
    1. Interface
    2. Constructor
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    // The issue arises because the transfer function in the IERC20 interface is likely marked as view, but your implementation modifies the state. To fix this, ensure the IERC20 interface defines transfer as nonpayable.
    // function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}
