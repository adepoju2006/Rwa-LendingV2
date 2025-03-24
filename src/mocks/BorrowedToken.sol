pragma solidity ^0.8.20;

import  {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BorrowedERC20Token is ERC20 {

    constructor(address to, uint256 totalSupply) ERC20("Borrowed Token","BRT") {
        _mint(to, totalSupply );
    }

}