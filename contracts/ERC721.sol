// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//  overide concept which uses parent contract function in it's own contract.(Inheritance)
interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract ERC721 is IERC721 {
    function setApprovalForAll(
        address operator,
        bool _approved
    ) external override {
        isApprovedForAll[msg.sender][operator] = _approved;
        emit ApprovalForAll(msg.sender, operator, _approved);
    }

    function getApproved(
        uint256 tokenId
    ) external view override returns (address operator) {
        require(_ownerOf[tokenId] != address(0), "token doesn't exist");
        return _approvals[tokenId];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override {
        require(_ownerOf[tokenId] != address(0), "token doesn't exist"); // Added check
        transferFrom(from, to, tokenId);

        require(
            to.code.length == 0 ||
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                ) ==
                IERC721Receiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    // Events from ERC721 standard
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Token ownership: tokenId => owner address
    mapping(uint256 => address) internal _ownerOf;

    // Owner balances: address => token count
    mapping(address => uint256) internal _balanceOf;

    // Approved address for each tokenId
    mapping(uint256 => address) internal _approvals;

    // Operator approvals: owner => (operator => approved)
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /* ========== ERC165 ========== */

    function supportsInterface(
        bytes4 interfaceID
    ) external pure override returns (bool) {
        // Added override
        return
            interfaceID == type(IERC721).interfaceId ||
            interfaceID == type(IERC165).interfaceId;
    }

    /* ========== View Functions ========== */

    // Returns balance (token count) of a specific owner
    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "zero address");
        return _balanceOf[owner];
    }

    // Returns current owner of a given tokenId
    function ownerOf(uint256 id) external view returns (address owner) {
        owner = _ownerOf[id];
        require(owner != address(0), "token doesn't exist");
    }

    function _isApprovedOrOwner(
        address owner,
        address spender,
        uint256 id
    ) internal view returns (bool) {
        return (spender == owner ||
            isApprovedForAll[owner][spender] ||
            spender == _approvals[id]);
    }

    function transferFrom(address from, address to, uint256 id) public {
        require(from == _ownerOf[id], "from != owner");
        require(to != address(0), "transfer to zero address");

        require(_isApprovedOrOwner(from, msg.sender, id), "not authorized");

        _balanceOf[from]--;
        _balanceOf[to]++;
        _ownerOf[id] = to;

        delete _approvals[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        require(_ownerOf[id] != address(0), "token doesn't exist"); // Added check
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    ""
                ) ==
                IERC721Receiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    function _mint(address to, uint256 id) internal {
        require(to != address(0), "mint to zero address");
        require(_ownerOf[id] == address(0), "already minted");

        _balanceOf[to] += 1;
        _ownerOf[id] = to;

        emit Transfer(address(0), to, id); // Standard mint event
    }

    function _burn(uint256 id) internal {
        address owner = _ownerOf[id];
        require(owner != address(0), "not minted"); // Make sure token exists

        _balanceOf[owner] -= 1;

        delete _ownerOf[id];

        // Only delete approval if it exists to save gas
        if (_approvals[id] != address(0)) {
            delete _approvals[id];
        }

        emit Transfer(owner, address(0), id); // Standard burn event
    }
}

contract MyNFT is ERC721 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function mint(address to, uint256 id) external onlyOwner {
        _mint(to, id);
    }

    function burn(uint256 id) external {
        require(msg.sender == _ownerOf[id], "not owner");
        _burn(id);
    }
}
