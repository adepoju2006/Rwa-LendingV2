// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Auction.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple Mock ERC721 for testing
contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}
    
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC721).interfaceId || super.supportsInterface(interfaceId);
    }
}

// Simple Mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AuctionContractTest is Test {
    AuctionContract public auctionContract;
    MockERC721 public mockNFT;
    MockERC20 public mockERC20;
    
    address public OWNER = address(0x1);
    address public LENDING_CONTRACT = address(0x2);
    address public BIDDER1 = address(0x3);
    address public BIDDER2 = address(0x4);
    
    function setUp() public {
        // Deploy mock contracts
        mockNFT = new MockERC721();
        mockERC20 = new MockERC20();
        
        // Setup users with ETH
        vm.deal(BIDDER1, 10 ether);
        vm.deal(BIDDER2, 10 ether);
        vm.deal(LENDING_CONTRACT, 1 ether);
        
        // Deploy auction contract
        vm.prank(OWNER);
        auctionContract = new AuctionContract(LENDING_CONTRACT);
    }
    
    // function test_SetLendPoolAddress() public {
    //     // Deploy with address(0)
    //     vm.prank(OWNER);
    //     // AuctionContract newAuctionContract = new AuctionContract(address(LENDING_CONTRACT));
        
    //     // Set lending pool address
    //     address newLendingContract = address(0x123);
    //     // console log the lending contract address
    //     console.log("be lending contract address: ", auctionContract.lendingContract());
    //     auctionContract.setLendPoolAddress(newLendingContract);
        
    //     // Verify address was set
    //     assertEq(auctionContract.lendingContract(), newLendingContract);
        
    //     // Verify it reverts when trying to set it again
    //     vm.expectRevert(abi.encodeWithSignature("LendPoolAddressAlreadySet()"));
    //     auctionContract.setLendPoolAddress(address(0x456));
    // }

    function test_StartAuction() public {
        // Try to start auction from unauthorized address
        vm.prank(OWNER);
        vm.expectRevert("Only lending contract can start auctions");
        auctionContract.startAuction(address(mockNFT), 1);
        
        // Start auction from lending contract
        vm.prank(LENDING_CONTRACT);
        auctionContract.startAuction(address(mockNFT), 1);
        
        // Verify auction was created correctly
        (
            address collateralAddress,
            uint256 collateralId,
            address highestBidder,
            uint256 highestBid,
            bool isActive
        ) = auctionContract.auctions(0);
        
        assertEq(collateralAddress, address(mockNFT));
        assertEq(collateralId, 1);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertTrue(isActive);
        assertEq(auctionContract.auctionCounter(), 1);
    }

 function test_PlaceBid() public {
    // Start an auction
    vm.prank(LENDING_CONTRACT);
    auctionContract.startAuction(address(mockNFT), 1);
    
    // Place first bid
    uint256 bidAmount1 = 1 ether;
    
    vm.prank(BIDDER1);
    auctionContract.placeBid{value: bidAmount1}(0);
    
    // Verify bid was placed
    (
        ,
        ,
        address highestBidder,
        uint256 highestBid,
        
    ) = auctionContract.auctions(0);
    
    assertEq(highestBidder, BIDDER1);
    assertEq(highestBid, bidAmount1);
    
    // Place higher bid
    uint256 bidAmount2 = 2 ether;
    
    // Check BIDDER2's balance before placing bid
    uint256 bidder2BalanceBefore = address(BIDDER2).balance;
    
    vm.prank(BIDDER2);
    auctionContract.placeBid{value: bidAmount2}(0);
    
    // Check BIDDER2's balance after placing bid
    uint256 bidder2BalanceAfter = address(BIDDER2).balance;
    
    // BIDDER2 spent 2 ether, so the balance should decrease by 2 ether
    assertEq(bidder2BalanceAfter, bidder2BalanceBefore - bidAmount2);
    
    // Verify new highest bid
    (
        ,
        ,
        address newHighestBidder,
        uint256 newHighestBid,
        
    ) = auctionContract.auctions(0);
    
    assertEq(newHighestBidder, BIDDER2);
    assertEq(newHighestBid, bidAmount2);
    
    // Try to place lower bid - should revert
    vm.expectRevert("Bid must be higher than current bid");
    vm.prank(BIDDER1);
    auctionContract.placeBid{value: 1.5 ether}(0);
}

    function test_EndAuction() public {
        // Start an auction
        vm.prank(LENDING_CONTRACT);
        auctionContract.startAuction(address(mockNFT), 1);
        
        // Place a bid
        uint256 bidAmount = 1 ether;
        // console BIDDER1 balance before placing bid
        uint256 bidder1BalanceBefore = address(BIDDER1).balance;
        console.log("Bidder1 balance before placing bid: ", bidder1BalanceBefore);
        vm.prank(BIDDER1);
        auctionContract.placeBid{value: bidAmount}(0);
        // console BIDDER1 balance after placing bid
        uint256 bidder1BalanceAfter = address(BIDDER1).balance;
        console.log("Bidder1 balance after placing bid: ", bidder1BalanceAfter);
        
        // Mint NFT to auction contract
        mockNFT.mint(address(auctionContract), 1);
        
        // Only lending contract can end auction
        vm.prank(OWNER);
        vm.expectRevert("Only lending contract can end auctions");
        auctionContract.endAuction(0);
        
        // Record balance before ending auction
        uint256 lendingContractBalanceBefore = address(LENDING_CONTRACT).balance;
        
        // Set up approvals for NFT transfer
        vm.prank(address(auctionContract));
        mockNFT.approve(BIDDER1, 1);

        // console log the auction balance
        uint256 auctionBalance = address(auctionContract).balance;
        console.log("Auction balance before ending auction: ", auctionBalance);
        
        // End auction from lending contract
        vm.prank(LENDING_CONTRACT);
        auctionContract.endAuction(0);
        
        // Verify auction is no longer active
        (
            ,
            ,
            ,
            ,
            bool isActive
        ) = auctionContract.auctions(0);
        
        assertFalse(isActive);
        
        // Verify NFT transferred to highest bidder
        assertEq(mockNFT.ownerOf(1), BIDDER1);
        
        // Verify funds transferred to lending contract
        uint256 lendingContractBalanceAfter = address(LENDING_CONTRACT).balance;
        assertEq(lendingContractBalanceAfter, lendingContractBalanceBefore + bidAmount);
    }
    
    // function test_EndAuctionERC20() public {
    //     // Start an auction with ERC20 token as collateral
    //     vm.prank(LENDING_CONTRACT);
    //     auctionContract.startAuction(address(mockERC20), 1000);
        
    //     // Place a bid
    //     uint256 bidAmount = 1 ether;
        
    //     vm.prank(BIDDER1);
    //     auctionContract.placeBid{value: bidAmount}(0);
        
    //     // Transfer ERC20 tokens to auction contract
    //     mockERC20.mint(address(auctionContract), 1000);
        
    //     // End auction from lending contract
    //     vm.prank(LENDING_CONTRACT);
    //     auctionContract.endAuction(0);
        
    //     // Verify ERC20 tokens transferred to highest bidder
    //     assertEq(mockERC20.balanceOf(BIDDER1), 1000);
    // }
}

//10000000000000000000
//11000000000000000000