## DCC Rwa Lending Contract

**how does it work?.**

This is a Lending platform whereby the Borrower Request for a Loan using `createLoan` function and will automatically put down his Collateral Token which could be `RWA Asset or ERC20 Token`, then the Lender use the `approveLoan` function to approve the Loan and send the Token also could be `RWA Asset or ERC20 Token`  intended to Lend to the Borrower. There is a Period of time the Borrower have to repay  the Loan which was setUp by the platform and also there is a `liquidationThreshold` and `interestRate` set by the Platform.

**Actors**
1. Borrowers: he will be requesting for Loan by putting down Collateral
2. Lenders: wil be Giving out Loan.

**Features**
1. Creation of Loan
2. Approval of Loan
3. Repayment of Loan
4. Liquidation of Loan
5. Auction Market for the Liquidated Position.

**how does the Liquidation work**
There are two ways a Position could be Liquidated which are:
1. if the Time given to repay Elapses
2. if the Position is Undercollateralized the Position is Liquidated.

**Aution Market**
The auction Market begins once a particular Position is Liquidated the Collateral of the Liquidated Position will be sent to the `AuctionContract` contract and there will be a Bidding process from the Bidders and the Highest Bidder take the Collateral after the end of the auction. 

**Stack**
1. Foundry framework
2. openzeppelin library
3. orochi-network library
 

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
