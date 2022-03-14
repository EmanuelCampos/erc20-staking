// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/ERC721A.sol";

contract BadassApeNFTClub is Ownable, ERC721A, ReentrancyGuard {
    bool public saleIsActive = false;
    bool public isAllowListActive= false;

    string private _baseURIextended;

    uint256 public constant MAX_SUPPLY = 8888;
    uint256 public constant MAX_PUBLIC_MINT = 3;
    uint256 public constant PRICE_PER_TOKEN_SALES = 0.15 ether;
    uint256 public constant PRICE_PER_TOKEN_PRE_SALES = 0.10 ether;

    bytes32 public merkleRoot = 0xd4453790033a2bd762f526409b7f358023773723d9e9bc42487e4996869162b6;

    mapping(address => uint256) private _allowList;
    mapping(address => uint256) private _allowListMerkleTree;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    constructor(
        string memory name,
        string memory symbol
    ) ERC721A(name, symbol) {
    }

    function setAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = numAllowedToMint;
        }
    }

    function numAvailableToMint(address addr) external view returns (uint256) {
        return _allowList[addr];
    }

    function mintAllowList(uint256 numberOfTokens, bytes32[] calldata _merkleProof, uint listType) external payable callerIsUser{
        require(isAllowListActive, "Allow list is not active");
        require(totalSupply() + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        
        require(listType == 0 || listType == 1, "Invalid list type");

        if(listType == 0) {
            require(numberOfTokens + _allowListMerkleTree[msg.sender] <= 2, "Exceeded max available to purchase");
            
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof");
            _allowListMerkleTree[msg.sender] += numberOfTokens;
        }

        if(listType == 1) {
            require(numberOfTokens <= _allowList[msg.sender], "Exceeded max available to purchase");
            _allowList[msg.sender] -= numberOfTokens;
        }
        
        _safeMint(msg.sender, numberOfTokens);
        refundIfOver(PRICE_PER_TOKEN_PRE_SALES * numberOfTokens);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function reserve(uint256 numberOfTokens) external onlyOwner {
        require(totalSupply() + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        _safeMint(msg.sender, numberOfTokens);
    }

    function setSaleState(bool newState) external onlyOwner {
        saleIsActive = newState;
    }

    function mint(uint256 numberOfTokens) external payable callerIsUser {
        require(numberOfTokens >= 1, "You must mint at least one token");
        require(saleIsActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(totalSupply() + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");

        _safeMint(msg.sender, numberOfTokens);
        refundIfOver(PRICE_PER_TOKEN_SALES * numberOfTokens);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "Ether value sent is not correct");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}