// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DCCRWANFT is ERC721, ERC721Enumerable, Ownable {
    using SafeERC20 for IERC20;

    error RWANFT__InvalidAddress();
    error RWANFT__BatchSize();
    error RWANFT__InsufficientFundsMint();
    error RWANFT__HousePrice();
    error Zero__InvalidAddress();

    IERC20 public token;
    // IRAACHousePrices publicoracle;
    address public oracle;

    uint256 public currentBatchSize = 3;
    //@audit-Low Unecessary Storage Read
    string public baseURI = "ipfs://QmZzEbTnUWs5JDzrLKQ9yGk1kvszdnwdMaVw9vNgjCFLo2/";

    event NFTMinted(address indexed minter, uint256 tokenId, uint256 price);
    event BaseURIUpdated(string uri);

    constructor(address _token, address _housePrices, address initialOwner)
        ERC721("DCC_RWA NFT", "DCCNFT")
        Ownable(initialOwner)
    {
        if (_token == address(0) || _housePrices == address(0) || initialOwner == address(0)) {
            revert RWANFT__InvalidAddress();
        }
        token = IERC20(_token);
        //oracle = IRAACHousePrices(_housePrices);
        oracle = _housePrices;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    //@audit-M  Missing tokenId Validation
    //audit-H Race Condition in Minting Process
    function mint(uint256 _tokenId, uint256 _amount) external {
        //price Feed to be Implemented.
        uint256 price = 1;

        if (price == 0) revert RWANFT__HousePrice();
        if (price > _amount) revert RWANFT__InsufficientFundsMint();
        //800 > 200 = revert
        // 1000
        // transfer erc20 from user to contract - requires pre-approval from user
        token.safeTransferFrom(msg.sender, address(this), _amount);

        // mint tokenId to user
        _safeMint(msg.sender, _tokenId);
        // 1000 - 800 = 200
        // If user approved more than necessary, refund the difference
        if (_amount > price) {
            uint256 refundAmount = _amount - price;
            token.safeTransfer(msg.sender, refundAmount);
        }

        emit NFTMinted(msg.sender, _tokenId, price);
    }

    // @audit-H Price Oracle manipulation
    // function getHousePrice(uint256 _tokenId) public view override returns(uint256) {
    //     returnoracle.tokenToHousePrice(_tokenId);
    // }

    //@audit-Low Unbounded Batch size
    function addNewBatch(uint256 _batchSize) public onlyOwner {
        if (_batchSize == 0) revert RWANFT__BatchSize();
        currentBatchSize += _batchSize;
    }

    //@audit-Low Centralization Risk
    function setBaseUri(string memory _uri) external onlyOwner {
        baseURI = _uri;
        emit BaseURIUpdated(_uri);
    }

    // function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable, IERC165) returns (bool) {//-
    //     return super.supportsInterface(interfaceId);//-
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        //+
        return interfaceId == type(IERC165).interfaceId || super.supportsInterface(interfaceId);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        if (account == address(0)) revert RWANFT__InvalidAddress();
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        if (to == address(0)) revert RWANFT__InvalidAddress();
        return super._update(to, tokenId, auth);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert Zero__InvalidAddress();
        token.safeTransfer(to, amount);
    }
}
