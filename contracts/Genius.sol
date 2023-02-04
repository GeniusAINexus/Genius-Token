pragma solidity ^0.8.17;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract Genius is ERC20 {
    string public name = "Genius AI";
    string public symbol = "Genius";
    uint8 public decimals = 18;
    uint public INITIAL_SUPPLY = 1000000000;
    constructor() public {
      _mint(msg.sender, INITIAL_SUPPLY);
    }



}
