// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Interface defining the standard ERC1155 functions
interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external;
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// Interface that contracts must implement to receive ERC1155 tokens safely
interface IERC1155TokenReceiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

// Implementation of the ERC1155 multi-token standard
contract ERC1155 is IERC1155 {
    // Events for token transfers and approval changes
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    // Mapping to store balances: owner => token ID => amount
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    // Mapping to store approvals: owner => operator => isApproved
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    // Batch balance check: returns an array of balances for multiple owner-tokenID pairs
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids) external view returns (uint256[] memory balances) {
        require(owners.length == ids.length, "owners length != ids length");
        balances = new uint256[](owners.length);
        unchecked {
            for (uint256 i = 0; i < owners.length; i++) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    // Allow or revoke permission for an operator to manage all of msg.sender's tokens
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // Transfer a single token safely
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "not approved");
        require(to != address(0), "to = 0 address");

        balanceOf[from][id] -= value;
        balanceOf[to][id] += value;

        emit TransferSingle(msg.sender, from, to, id, value);

        // If recipient is a contract, ensure it accepts ERC1155 tokens
        if (to.code.length > 0) {
            require(
                IERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, value, data) ==
                    IERC1155TokenReceiver.onERC1155Received.selector,
                "unsafe transfer"
            );
        }
    }

    // Transfer multiple token types safely in a batch
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "not approved");
        require(to != address(0), "to = 0 address");
        require(ids.length == values.length, "ids length != values length");

        for (uint256 i = 0; i < ids.length; i++) {
            balanceOf[from][ids[i]] -= values[i];
            balanceOf[to][ids[i]] += values[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        // Check if recipient contract accepts batch tokens
        if (to.code.length > 0) {
            require(
                IERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, values, data) ==
                    IERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "unsafe transfer"
            );
        }
    }

    // Check which interfaces are supported (ERC165 standard)
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0xd9b67a26 // ERC1155
            || interfaceId == 0x0e89341c; // ERC1155 Metadata URI
    }

    // Virtual function for returning metadata URI of a token (to be overridden)
    function uri(uint256 id) public view virtual returns (string memory) {}

    // ======================== Internal Mint/Burn Helpers ========================

    // Mint a new token (single)
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        require(to != address(0), "to = 0 address");
        balanceOf[to][id] += value;

        emit TransferSingle(msg.sender, address(0), to, id, value);

        // If sending to a contract, check it can handle ERC1155
        if (to.code.length > 0) {
            require(
                IERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, value, data) ==
                    IERC1155TokenReceiver.onERC1155Received.selector,
                "unsafe transfer"
            );
        }
    }

    // Mint multiple token types in a batch
    function _batchMint(address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) internal {
        require(to != address(0), "to = 0 address");
        require(ids.length == values.length, "ids length != values length");

        for (uint256 i = 0; i < ids.length; i++) {
            balanceOf[to][ids[i]] += values[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        if (to.code.length > 0) {
            require(
                IERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, values, data) ==
                    IERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "unsafe transfer"
            );
        }
    }

    // Burn (destroy) a single token from an address
    function _burn(address from, uint256 id, uint256 value) internal {
        require(from != address(0), "from = 0 address");
        balanceOf[from][id] -= value;
        emit TransferSingle(msg.sender, from, address(0), id, value);
    }

    // Burn multiple token types from an address
    function _batchBurn(address from, uint256[] calldata ids, uint256[] calldata values) internal {
        require(from != address(0), "from = 0 address");
        require(ids.length == values.length, "ids length != values length");

        for (uint256 i = 0; i < ids.length; i++) {
            balanceOf[from][ids[i]] -= values[i];
        }

        emit TransferBatch(msg.sender, from, address(0), ids, values);
    }
}

// Custom contract extending ERC1155 to allow public minting and burning
contract MyMultiToken is ERC1155 {
    // Public mint function to mint a specific token ID and value
    function mint(uint256 id, uint256 value, bytes memory data) external {
        _mint(msg.sender, id, value, data);
    }

    // Public batch mint function for minting multiple token IDs at once
    function batchMint(uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external {
        _batchMint(msg.sender, ids, values, data);
    }

    // Public burn function to destroy a specific token from the caller
    function burn(uint256 id, uint256 value) external {
        _burn(msg.sender, id, value);
    }

    // Public batch burn function to destroy multiple tokens from the caller
    function batchBurn(uint256[] calldata ids, uint256[] calldata values) external {
        _batchBurn(msg.sender, ids, values);
    }
}
