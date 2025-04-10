// pragma solidity ^0.8.20;

// import {Test, console} from "forge-std/Test.sol";
// import {Script} from "forge-std/Script.sol";
// import {DCCRwaLending} from "../src/LendPool.sol";
// import "../src/Auction.sol";
// import {BorrowedERC20Token} from "../src/mocks/BorrowedToken.sol";
// import {CollateralERC20Token} from "../src/mocks/CollateralToken.sol";

// contract LendPoolTest is Test, Script {
// DCCRwaLending dccRwaLending;
// AuctionContract auction;
// BorrowedERC20Token borrowedERC20Token;
// CollateralERC20Token collateralERC20Token;
// address LENDER = makeAddr("Lender");
// address BORROWER = makeAddr("Borrower");
// address public Oracle = "0x";
// uint256 public liquidationThreshold = 80;
// uint256 LenderBalance = 1000000e18;
// uint256 BorrowerBalance = 1000000e18;

// enum AssetType {
//     TOKEN,
//     RWA
// }

//     function setUp() public {
//         dccRwaLending = new DCCRwaLending(
//             Oracle,
//             liquidationThreshold,
//             address(this)
//         );
//         auction = new AuctionContract(address(dccRwaLending));
//         borrowedERC20Token = new BorrowedERC20Token(LENDER, LenderBalance);
//         collateralERC20Token = new CollateralERC20Token(BORROWER, BorrowerBalance);

//         //aprrove token
//         vm.prank(BORROWER);
//          borrowedERC20Token.approve(address(dccRwaLending), type(uint256).max);
//          collateralERC20Token.approve(address(dccRwaLending), type(uint256).max);

//           vm.prank(LENDER);
//          collateralERC20Token.approve(address(dccRwaLending), type(uint256).max);
//          borrowedERC20Token.approve(address(dccRwaLending), type(uint256).max);

//     }

//     function test_CreateLoan() public {

//         uint256 initialBalanceOfBorrower = collateralERC20Token.balanceOf(BORROWER);
//          console.log("initialBalanceOfBorrower:", initialBalanceOfBorrower);

//         vm.startPrank(BORROWER);
//         dccRwaLending.createLoan(
//             AssetType.TOKEN,
//             address(collateralERC20Token),
//             10000e18,
//             AssetType.TOKEN,
//             address(borrowedERC20Token),
//             2000e18
//         );
//       vm.stopPrank();

//    uint256 finalBalanceOfBorrower = collateralERC20Token.balanceOf(BORROWER);
//          console.log("FinalBalanceOfBorrower:" , finalBalanceOfBorrower);

//     }
//     function testApproveLoan() public {

//     }
//     function testRepayLoan() public {

//     }
//      function testLiquidateLoan() public {

//     }
// }
