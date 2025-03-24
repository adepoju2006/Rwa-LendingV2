// AuctionContract.sol
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts//utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract AuctionContract is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error  LendPoolAddressAlreadySet();

    struct Auction {
        address collateralAddress;
        uint256 collateralId;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;
    address public lendingContract;

    event AuctionStarted(uint256 auctionId, address collateralAddress, uint256 collateralId);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount);

    constructor(address _lendingContract) {
        if(_lendingContract == address(0)) revert LendPoolAddressAlreadySet();
        lendingContract = _lendingContract;
    }


   function setLendPoolAddress(address _lendPoolContract) external {
        // require(l_endPoolContract == address(0), "LendPool address already set");
        if(_lendPoolContract == address(0)) revert LendPoolAddressAlreadySet();
        lendingContract = _lendPoolContract;
    }
    function startAuction(address _collateralAddress, uint256 _collateralId) external {
        require(msg.sender == lendingContract, "Only lending contract can start auctions");

        auctions[auctionCounter] = Auction({
            collateralAddress: _collateralAddress,
            collateralId: _collateralId,
            highestBidder: address(0),
            highestBid: 0,
            isActive: true
        });

        emit AuctionStarted(auctionCounter, _collateralAddress, _collateralId);
        auctionCounter++;
    }

    function placeBid(uint256 _auctionId) external payable nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.isActive, "Auction is not active");
        require(msg.value > auction.highestBid, "Bid must be higher than current bid");

        // Update highest bidder and bid
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.isActive, "Auction is not active");
        require(msg.sender == lendingContract, "Only lending contract can end auctions");

        // Transfer collateral to the highest bidder
        if (IERC721(auction.collateralAddress).supportsInterface(type(IERC721).interfaceId)) {
            IERC721(auction.collateralAddress).transferFrom(address(this), auction.highestBidder, auction.collateralId);
        } else {
            IERC20(auction.collateralAddress).safeTransfer(auction.highestBidder, auction.collateralId);
        }

        // Transfer proceeds to the lending contract
        payable(lendingContract).transfer(auction.highestBid);

        auction.isActive = false;
        emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
    }

    
}