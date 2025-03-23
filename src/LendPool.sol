pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts//utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Auction.sol";

// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

 contract DCCRwaLending is ReentrancyGuard, Ownable {

  using SafeERC20 for IERC20;

  error LoanIsNotActive();
  error LoanAlreadyHasLender();
  error OnlyBorrowerCanPay();
  error LoanDurationNotExpiredOrUndercollateralized();
  error Invalid_ZeroAddress();
  error AuctionAddressAlreadySet();

    enum AssetType {
         TOKEN,
          RWA
     }

    struct Loan {
        uint256 loanId;
        AssetType collateralType;
        address collateralAddress; // Address of the token or RWA contract
        uint256 collateralId; // Token ID for ERC-721 or amount for ERC-20
        AssetType borrowedType;
        address borrowedAddress; // Address of the borrowed asset contract
        uint256 borrowedAmount;
        uint256 interestRate;
        uint256 duration;
        address borrower;
        address lender;
        bool isActive;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;
    address public auctionContract;
    address public oracle; // Chainlink oracle for price feeds
    uint256 public liquidationThreshold; // e.g., 150% (1.5 * 100)
    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public INTEREST_RATE = 5;
     uint256 public Duration = block.timestamp + 30 days;
    //  address public initialOwner = msg.sender;

    event LoanCreated(uint256 loanId, address borrower, AssetType collateralType, AssetType borrowedType, uint256 borrowedAmount);
    event LoanApproved(uint256 loanId, address lender);
    event LoanRepaid(uint256 loanId);
    event LoanLiquidated(uint256 loanId, address liquidator);
    event CollateralSentToAuction(uint256 loanId, address collateralAddress, uint256 collateralId);

    constructor(
    address _oracle, 
    uint256 _liquidationThreshold,
     address  initialOwner) Ownable(initialOwner){
        oracle = _oracle;
        liquidationThreshold = _liquidationThreshold; // 150 150%;
     
    }

    function setAuctionAddress(address _auctionContract) external onlyOwner {
        // require(auctionContract == address(0), "Auction address already set");
        if(auctionContract == address(0)) revert AuctionAddressAlreadySet();
        auctionContract = _auctionContract;
    }

    function setInterestRate(uint256 _interestRate) external onlyOwner {    
         INTEREST_RATE = _interestRate;
    }
     
     function setDuration(uint256 _duration) external onlyOwner {
         Duration  = _duration;
     }
  ////////////////////////////////////
  //       BORROWER FUNCTION        //
  //////////////////////////////////

    function createLoan(
        AssetType _collateralType,
        address _collateralAddress,
        uint256 _collateralId,
        AssetType _borrowedType,
        address _borrowedAddress,
        uint256 _borrowedAmount
       
    ) external {
        
        if(_collateralAddress == address(0) &&   _borrowedAddress == address(0)) revert Invalid_ZeroAddress();

        if (_collateralType == AssetType.TOKEN) {
            IERC20(_collateralAddress).safeTransferFrom(msg.sender, address(this), _collateralId);
        } else if (_collateralType == AssetType.RWA) {
            IERC721(_collateralAddress).transferFrom(msg.sender, address(this), _collateralId);
        }

        loans[loanCounter] = Loan({
            loanId: loanCounter,
            collateralType: _collateralType,
            collateralAddress: _collateralAddress,
            collateralId: _collateralId,
            borrowedType: _borrowedType,
            borrowedAddress: _borrowedAddress,
            borrowedAmount: _borrowedAmount,
            interestRate: INTEREST_RATE,
            duration:  Duration,
            borrower: msg.sender,
            lender: address(0),
            isActive: true
        });

        emit LoanCreated(loanCounter, msg.sender, _collateralType, _borrowedType, _borrowedAmount);
        loanCounter++;
    }

        //////////////////////////////////
        //     LENDER FUNCTION          //
       //////////////////////////////////
    function approveLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        // require(loan.isActive, "Loan is not active");
        if(!loan.isActive) {revert LoanIsNotActive();}
        // require(loan.lender == address(0), "Loan already has a lender");
        if(loan.lender == address(0)) { revert LoanAlreadyHasLender();}

        if (loan.borrowedType == AssetType.TOKEN) {
            IERC20(loan.borrowedAddress).safeTransferFrom(msg.sender, loan.borrower, loan.borrowedAmount);
        } else if (loan.borrowedType == AssetType.RWA) {
            IERC721(loan.borrowedAddress).transferFrom(msg.sender, loan.borrower, loan.borrowedAmount);
        }

        loan.lender = msg.sender;
        emit LoanApproved(_loanId, msg.sender);
    }

     
       ////////////////////////////////////
       //       BORROWER FUNCTION        //
       //////////////////////////////////

    function repayLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
         if(!loan.isActive) {revert LoanIsNotActive();}
        if(msg.sender != loan.borrower) {revert OnlyBorrowerCanPay();}

        uint256 repaymentAmount = loan.borrowedAmount + (loan.borrowedAmount * loan.interestRate / 100);

        if (loan.borrowedType == AssetType.TOKEN) {
            IERC20(loan.borrowedAddress).safeTransferFrom(msg.sender, loan.lender, repaymentAmount);
        } else if (loan.borrowedType == AssetType.RWA) {
            IERC721(loan.borrowedAddress).transferFrom(msg.sender, loan.lender, repaymentAmount);
        }

        if (loan.collateralType == AssetType.TOKEN) {
            IERC20(loan.collateralAddress).safeTransfer(msg.sender, loan.collateralId);
        } else if (loan.collateralType == AssetType.RWA) {
            IERC721(loan.collateralAddress).transferFrom(address(this), msg.sender, loan.collateralId);
        }

        loan.isActive = false;
        emit LoanRepaid(_loanId);
    }

     // Withraw Auction Funds
    function withdraw(address to, uint256 amount) external onlyOwner{
        if(to == address(0)) revert Invalid_ZeroAddress();
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer Failed");
     }

     ////////////////////////////////////
    //       EVERYONE FUNCTION        //
    //////////////////////////////////
    function liquidateLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
    
         if(!loan.isActive) {revert LoanIsNotActive();}
        // if(block.timestamp < loan.duration) { revert LoanDurationNotExpired();}

        uint256 healthFactor = getHealthFactor(_loanId);
         bool isUnderCollateralized = healthFactor <= liquidationThreshold;

        bool isLoanExpired = block.timestamp > loan.duration;

        if(!isUnderCollateralized && !isLoanExpired) revert LoanDurationNotExpiredOrUndercollateralized();


        if (loan.collateralType == AssetType.TOKEN) {
            IERC20(loan.collateralAddress).safeTransfer(auctionContract, loan.collateralId);
        } else if (loan.collateralType == AssetType.RWA) {
            IERC721(loan.collateralAddress).transferFrom(address(this), auctionContract, loan.collateralId);
        }
       
       AuctionContract(auctionContract).startAuction(loan.collateralAddress, loan.collateralId);

        emit CollateralSentToAuction(_loanId, loan.collateralAddress, loan.collateralId);
        loan.isActive = false;
        emit LoanLiquidated(_loanId, msg.sender);
    }

    

   function getHealthFactor(uint256 _loanId) public view returns (uint256) {
        Loan storage loan = loans[_loanId];
        // require(loan.isActive, "Loan is not active");
         if(!loan.isActive) {revert LoanIsNotActive();}

        // Fetch prices from oracle
        uint256 collateralPrice = getPrice(loan.collateralAddress);
        uint256 borrowedPrice = getPrice(loan.borrowedAddress);

        // Calculate collateral and loan values with precision
        uint256 collateralValue = (loan.collateralId * collateralPrice) / PRICE_PRECISION;
        uint256 loanValue = (loan.borrowedAmount * borrowedPrice) / PRICE_PRECISION;

        // Calculate health factor
        if (loanValue == 0) return type(uint256).max; // Avoid division by zero
        return (collateralValue * 100) / loanValue;
    }
    function getPrice(address _asset) internal pure  returns (uint256) {
        // Fetch price from Chainlink oracle
        // (, int256 price, , , ) = AggregatorV3Interface(oracle).latestRoundData();
        // require(price > 0, "Invalid price");
        // return uint256(price);
        // Price feed function to be Implemented
            uint256 price = 200;

            return price;
    }
}