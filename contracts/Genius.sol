pragma solidity ^0.8.4;

// import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Taxable.sol";

contract Genius is ReentrancyGuard, ERC20, AccessControl, Taxable  {
    
    uint public INITIAL_SUPPLY = 999999999 * (10 ** 18);

    bytes32 public constant NOT_TAXED_FROM = keccak256("NOT_TAXED_FROM");
    bytes32 public constant NOT_TAXED_TO = keccak256("NOT_TAXED_TO");
    bytes32 public constant ALWAYS_TAXED_FROM = keccak256("ALWAYS_TAXED_FROM");
    bytes32 public constant ALWAYS_TAXED_TO = keccak256("ALWAYS_TAXED_TO");


    constructor(
        string memory __name,
        string memory __symbol,
        bool __taxed,
        uint __thetax,
        uint __maxtax,
        uint __mintax,
        address __owner
        ) ERC20(__name, __symbol)
        Taxable(__taxed, __thetax, __maxtax, __mintax, __owner) {
        _mint(__owner, INITIAL_SUPPLY);
        _grantRole(DEFAULT_ADMIN_ROLE, __owner);
        _grantRole(NOT_TAXED_FROM, __owner);
        _grantRole(NOT_TAXED_TO, __owner);
        _grantRole(NOT_TAXED_FROM, address(this));
        _grantRole(NOT_TAXED_TO, address(this));
    }
    function enableTax() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _taxon();
    }

    function disableTax() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _taxoff();
    }

    function updateTax(uint newtax) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updatetax(newtax);
    }

    function updateTaxDestination(address newdestination) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updatetaxdestination(newdestination);
    }

   function _transfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20)
        nonReentrant
    {
        if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            super._transfer(from, to, amount);
        } else {
            if((hasRole(NOT_TAXED_FROM, from) || hasRole(NOT_TAXED_TO, to) || !taxed())
            && !hasRole(ALWAYS_TAXED_FROM, from) && !hasRole(ALWAYS_TAXED_TO, to)) {
                super._transfer(from, to, amount);
            } else { 
                require(balanceOf(from) >= amount, "Error: transfer amount exceeds balance");
                super._transfer(from, taxdestination(), amount*thetax()/10000); 
                super._transfer(from, to, amount*(10000-thetax())/10000);
            }
        }
    }


}
