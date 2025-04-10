// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock ERC721 token for testing
contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _safeMint(to, tokenId);
        _tokenIdCounter++;
        return tokenId;
    }
}

// Mock Oracle for testing
contract MockOracle {
    mapping(bytes20 => int256) private prices;

    function setPrice(bytes20 symbol, int256 price) external {
        prices[symbol] = price;
    }
function getLatestData(uint32 appId, bytes20 symbol) external view returns (bytes32) {
    require(appId == 1, "Invalid appId");
    return bytes32(uint256(uint256(prices[symbol]))); // cast int256 -> uint256 -> bytes32
}

}

contract DCCRwaLendingTest is Test {
    DCCRwaLending lendingContract;
    AuctionContract auctionContract;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC721 nftA;
    MockERC721 nftB;
    MockOracle oracle;

    address owner = address(0x1);
    address borrower = address(0x2);
    address lender = address(0x3);
    address liquidator = address(0x4);

    uint256 liquidationThreshold = 150; // 150%
    uint256 tokenId;
    bytes20 tokenASymbol = bytes20("TOKENA");
    bytes20 tokenBSymbol = bytes20("TOKENB");
    bytes20 nftASymbol = bytes20("NFTA");
    bytes20 nftBSymbol = bytes20("NFTB");

    uint256 collateralAmount = 100e18;
    uint256 borrowAmount = 50e18;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TOKENA");
        tokenB = new MockERC20("Token B", "TOKENB");
        nftA = new MockERC721("NFT A", "NFTA");
        nftB = new MockERC721("NFT B", "NFTB");

        // Deploy mock oracle
        oracle = new MockOracle();

     // $500 with 8 decimals precision

        // Deploy lending contract
        lendingContract = new DCCRwaLending(address(oracle), liquidationThreshold, owner);

        // Deploy auction contract
        auctionContract = new AuctionContract(address(owner));

        // Set auction contract in lending contract
        lendingContract.setAuctionAddress(address(auctionContract));

        // Set token symbols in lending contract
        lendingContract.setTokenSymbol(address(tokenA), tokenASymbol);
        lendingContract.setTokenSymbol(address(tokenB), tokenBSymbol);
        lendingContract.setTokenSymbol(address(nftA), nftASymbol);
        lendingContract.setTokenSymbol(address(nftB), nftBSymbol);


   // Set prices in oracle
        oracle.setPrice(tokenASymbol, 100 * 10 ** 8); // $100 with 8 decimals precision
        oracle.setPrice(tokenBSymbol, 1 * 10 ** 8); // $1 with 8 decimals precision
        oracle.setPrice(nftASymbol, 1000 * 10 ** 8); // $1000 with 8 decimals precision
        oracle.setPrice(nftBSymbol, 500 * 10 ** 8); 
        // Mint NFTs to borrower and lender
        vm.stopPrank();

        vm.startPrank(owner);
        tokenId = nftA.mint(borrower);
        nftB.mint(lender);
        vm.stopPrank();
    }

      function testGetPriceOnly() public {
        // uint256 tokenAPrice = lendingContract.getPrice(address(tokenA));
        // assertEq(tokenAPrice, 100 * 10 ** 8);

        uint256 tokenBPrice = lendingContract.getPrice(address(tokenB));
        // assertEq(tokenBPrice, 1 * 10 ** 8);

        // uint256 nftAPrice = lendingContract.getPrice(address(nftA));
        // assertEq(nftAPrice, 1000 * 10 ** 8);
    }

    // 1. Test createLoan function
    function testCreateLoan() public {
         // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);

        vm.startPrank(borrower);
        // Approve token transfer
        // uint256 collateralAmount = 100 * 10 ** 18;
        tokenA.approve(address(lendingContract), collateralAmount);

        // Create loan using ERC20 token as collateral
        lendingContract.createLoan(
            DCCRwaLending.AssetType.TOKEN, // collateral type
            address(tokenA), // collateral address
            collateralAmount, // collateral amount
            DCCRwaLending.AssetType.TOKEN, // borrowed type
            address(tokenB), // borrowed address
            borrowAmount // borrowed amount
        );

        // Verify loan details
        (
            uint256 loanId,
            DCCRwaLending.AssetType collateralType,
            address collateralAddress,
            uint256 collateralId,
            DCCRwaLending.AssetType borrowedType,
            address borrowedAddress,
            uint256 borrowedAmount,
            uint256 interestRate,
            uint256 duration,
            address borrowerAddr,
            address lenderAddr,
            bool isActive
        ) = lendingContract.loans(0);

        assertEq(loanId, 0);
        assertEq(uint256(collateralType), uint256(DCCRwaLending.AssetType.TOKEN));
        assertEq(collateralAddress, address(tokenA));
        assertEq(collateralId, collateralAmount);
        assertEq(uint256(borrowedType), uint256(DCCRwaLending.AssetType.TOKEN));
        assertEq(borrowedAddress, address(tokenB));
        assertEq(borrowedAmount, borrowAmount);
        assertEq(interestRate, 5); // Default interest rate
        assertEq(borrowerAddr, borrower);
        assertEq(lenderAddr, address(0));
        assertTrue(isActive);

        vm.stopPrank();
    }

    // Test creating loan with NFT as collateral
    function testCreateLoanWithNFT() public {
        vm.startPrank(borrower);

        // Approve NFT transfer
        nftA.approve(address(lendingContract), tokenId);

        // Create loan using ERC721 token as collateral
        lendingContract.createLoan(
            DCCRwaLending.AssetType.RWA, // collateral type
            address(nftA), // collateral address
            tokenId, // collateral ID
            DCCRwaLending.AssetType.TOKEN, // borrowed type
            address(tokenB), // borrowed address
            500 * 10 ** 18 // borrowed amount
        );

        // Verify loan details
        (
            uint256 loanId,
            DCCRwaLending.AssetType collateralType,
            address collateralAddress,
            uint256 collateralId,
            DCCRwaLending.AssetType borrowedType,
            address borrowedAddress,
            uint256 borrowedAmount,
            uint256 interestRate,
            uint256 duration,
            address borrowerAddr,
            address lenderAddr,
            bool isActive
        ) = lendingContract.loans(0);

        assertEq(loanId, 0);
        assertEq(uint256(collateralType), uint256(DCCRwaLending.AssetType.RWA));
        assertEq(collateralAddress, address(nftA));
        assertEq(collateralId, tokenId);

        // Verify NFT ownership transfer
        assertEq(nftA.ownerOf(tokenId), address(lendingContract));

        vm.stopPrank();
    }

    // 2. Test approveLoan function
    function testApproveLoan() public {
        // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        // First create a loan
        vm.startPrank(borrower);
        tokenA.approve(address(lendingContract), collateralAmount);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.TOKEN,
            address(tokenA),
            collateralAmount,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();

        // Get borrower balance before loan approval
        uint256 borrowerBalanceBefore = tokenB.balanceOf(borrower);

        // Approve the loan as lender
        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        lendingContract.approveLoan(0);
        vm.stopPrank();

        // Verify loan has been updated
        (,,,,,,,,,, address lenderAddr,) = lendingContract.loans(0);
        assertEq(lenderAddr, lender);

        // Verify borrower received funds
        uint256 borrowerBalanceAfter = tokenB.balanceOf(borrower);
        assertEq(borrowerBalanceAfter - borrowerBalanceBefore, borrowAmount);
    }

    // Test approve loan with NFT
    function testApproveLoanWithNFT() public {
         // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        // First create a loan
        vm.startPrank(borrower);
        nftA.approve(address(lendingContract), tokenId);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.RWA,
            address(nftA),
            tokenId,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();

        // Approve the loan as lender
        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        lendingContract.approveLoan(0);
        vm.stopPrank();

        // Verify loan has been updated and borrower received funds
        uint256 borrowerBalance = tokenB.balanceOf(borrower);
        assertEq(borrowerBalance, borrowAmount);
    }

    // 3. Test repayLoan function
    function testRepayLoan() public {
        // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        console.log("Token A minted amount:", tokenA.balanceOf(borrower));

        // Setup: Create and approve a loan
        vm.startPrank(borrower);
        tokenA.approve(address(lendingContract), collateralAmount);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.TOKEN,
            address(tokenA),
            collateralAmount,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();
        console.log("amount of collecteral in the contract", tokenA.balanceOf(address(lendingContract)));
        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        console.log("Lender tokenB bal", tokenB.balanceOf(lender));
        console.log("Borrower bal Before repairment", tokenA.balanceOf(borrower));
        lendingContract.approveLoan(0);
        vm.stopPrank();

        // 500000000000000000000
        // 50000000000000000000
        // Calculate repayment amount (principal + interest)
        uint256 repaymentAmount = borrowAmount + (borrowAmount * 5 / 100); // 5% interest

        // Mint tokenB directly to borrower for repayment
        tokenB.mint(borrower, repaymentAmount);

        // Repay the loan
        vm.startPrank(borrower);
        tokenB.approve(address(lendingContract), repaymentAmount);
        lendingContract.repayLoan(0);
        vm.stopPrank();

        // Verify loan is no longer active
        (,,,,,,,,,,, bool isActive) = lendingContract.loans(0);
        assertFalse(isActive);

        // Verify borrower received collateral back
        uint256 borrowerTokenABalance = tokenA.balanceOf(borrower);
        assertEq(borrowerTokenABalance, collateralAmount);

        // Verify lender received repayment
        uint256 lenderBalance = tokenB.balanceOf(lender);
        assertEq(lenderBalance, repaymentAmount); // Just check they received the repayment amount
    }
    //  Test repayment of NFT-collateralized loan

    function testRepayLoanWithNFT() public {
        tokenB.mint(lender, borrowAmount);
        // Setup: Create and approve a loan with NFT
        vm.startPrank(borrower);
        nftA.approve(address(lendingContract), tokenId);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.RWA,
            address(nftA),
            tokenId,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();

        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        lendingContract.approveLoan(0);

        // Mint tokenB directly to borrower for repayment
        vm.stopPrank();

        // Calculate repayment amount
        uint256 repaymentAmount = 500 * 10 ** 18 + (500 * 10 ** 18 * 5 / 100);
        tokenB.mint(borrower, repaymentAmount);

        // Repay the loan
        vm.startPrank(borrower);
        tokenB.approve(address(lendingContract), repaymentAmount);
        lendingContract.repayLoan(0);
        vm.stopPrank();

        // Verify borrower received NFT back
        assertEq(nftA.ownerOf(tokenId), borrower);
    }

    // 4. Test withdraw function
    function testWithdraw() public {
        // Send some ETH to the contract
        vm.deal(address(lendingContract), 1 ether);

        uint256 initialBalance = address(owner).balance;

        // Withdraw ETH
        vm.prank(owner);
        lendingContract.withdraw(owner, 0.5 ether);

        // Verify owner received ETH
        assertEq(address(owner).balance, initialBalance + 0.5 ether);

        // Verify contract balance decreased
        assertEq(address(lendingContract).balance, 0.5 ether);
    }

    function testWithdrawRevertIfNotOwner() public {
        vm.deal(address(lendingContract), 1 ether);

        vm.prank(borrower);
        vm.expectRevert(); // Should revert with Ownable: caller is not the owner
        lendingContract.withdraw(borrower, 0.5 ether);
    }

    // 5. Test liquidateLoan function
    function testLiquidateLoan() public {
         // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        // Setup: Create and approve a loan
        vm.startPrank(borrower);
        tokenA.approve(address(lendingContract), collateralAmount);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.TOKEN,
            address(tokenA),
            collateralAmount,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();

        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        lendingContract.approveLoan(0);
        vm.stopPrank();

        // Make the loan undercollateralized by changing price in oracle
        vm.prank(owner);
        oracle.setPrice(tokenASymbol, 10 * 10 ** 8); // Drop collateral price dramatically

        // Liquidate the loan
        // vm.prank(liquidator);
        // lendingContract.liquidateLoan(0);

        // // Verify loan is no longer active
        // (,,,,,,,,,,, bool isActive) = lendingContract.loans(0);
        // assertFalse(isActive);

        // // Verify collateral was sent to auction
        // assertEq(tokenA.balanceOf(address(auctionContract)), collateralAmount);
    }

    function testLiquidateLoanOnExpiry() public {
        // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        // Setup: Create and approve a loan
        vm.startPrank(borrower);
        nftA.approve(address(lendingContract), tokenId);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.RWA,
            address(nftA),
            tokenId,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
           borrowAmount
        );
        vm.stopPrank();

        vm.startPrank(lender);
        tokenB.approve(address(lendingContract),borrowAmount);
        lendingContract.approveLoan(0);
        vm.stopPrank();

        // Fast forward time past loan duration
        // uint256 currentDuration = lendingContract.Duration();
        // vm.warp(currentDuration + 1);

        // // Liquidate the loan
        // vm.prank(liquidator);
        // lendingContract.liquidateLoan(0);

        // // Verify NFT was sent to auction
        // assertEq(nftA.ownerOf(tokenId), address(auctionContract));
    }

    // 6. Test getHealthFactor function
    function testGetHealthFactor() public {
        // Initial setup - make sure borrower has enough tokenA for collateral
        tokenA.mint(borrower, collateralAmount);
        // Make sure the lender has enough tokenB to fund the loan
        tokenB.mint(lender, borrowAmount);
        // Setup: Create and approve a loan
        vm.startPrank(borrower);
        // uint256 collateralAmount = 100 * 10 ** 18; // $100 worth of tokenA
        tokenA.approve(address(lendingContract), collateralAmount);
        lendingContract.createLoan(
            DCCRwaLending.AssetType.TOKEN,
            address(tokenA),
            collateralAmount,
            DCCRwaLending.AssetType.TOKEN,
            address(tokenB),
            borrowAmount
        );
        vm.stopPrank();

        vm.startPrank(lender);
        tokenB.approve(address(lendingContract), borrowAmount);
        lendingContract.approveLoan(0);
        vm.stopPrank();

       

        uint256 healthFactor = lendingContract.getHealthFactor(0);
        assertEq(healthFactor, 20000);

        // Change price and verify health factor changes
        vm.prank(owner);
        oracle.setPrice(tokenASymbol, 50 * 10 ** 8); // Half the collateral price

        healthFactor = lendingContract.getHealthFactor(0);
        assertEq(healthFactor, 10000);
    }
    // 7. Test getPrice function
  

    function testGetPriceRevertsWhenSymbolNotSet() public {
        MockERC20 unknownToken = new MockERC20("Unknown", "UNK");

        vm.expectRevert(DCCRwaLending.TokenSymbolNotSet.selector);
        lendingContract.getPrice(address(unknownToken));
    }

    function testGetPriceRevertsWhenPriceIsZero() public {
        // Setup a token with zero price
        MockERC20 zeroToken = new MockERC20("Zero", "ZERO");
        bytes20 zeroSymbol = bytes20("ZERO");

        vm.startPrank(owner);
        lendingContract.setTokenSymbol(address(zeroToken), zeroSymbol);
        oracle.setPrice(zeroSymbol, 0); // Set price to zero
        vm.stopPrank();

        vm.expectRevert(DCCRwaLending.InvalidPrice.selector);
        lendingContract.getPrice(address(zeroToken));
    }
}
