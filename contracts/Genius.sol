pragma solidity ^0.8.4;

// import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Taxable.sol";

contract Genius is ReentrancyGuard, ERC20, AccessControl, Taxable  {
    
    uint public INITIAL_SUPPLY = 195000000 * (10 ** 18);
    uint public monthlyDevFund = (10 ** 7) * (10 ** 18);
    uint public nextRedeemTime;
    address devFundAddress;
    uint256 public deploymentBlockTime;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bytes32 public constant NOT_TAXED_FROM = keccak256("NOT_TAXED_FROM");
    bytes32 public constant NOT_TAXED_TO = keccak256("NOT_TAXED_TO");
    mapping (address => bool) public blacklist;
    uint256 public startPrice; // per wei
    mapping(address => uint256) public lockTimestamps;
    address[] public buyers;

    bool buyingEnabled = true;
    bool devFundEnabled = true;

    // Staking Function: the ability to stake tokens to earn more tokens (can unstake at any time)
    // APY is 25% per year and reduced by 1% each month but no less than 3% per year
    uint256 constant MIN_APY = 3;
    uint256 constant INITIAL_APY = 25;
    uint256 constant MONTHLY_APY_DECREASE = 1;

    struct User {
        uint256 lastClaimTime;
        uint256 stakedAmount;
        uint256 earnedAmount;
    }

    mapping(address => User) public users;
    mapping(address => bool) public airdroppedUsers;
    uint256 public totalStakedAmount;

    event Staked(address indexed staker, uint256 stakedAmount);
    event Unstaked(address indexed staker, uint256 unstakedAmount);
    event EarningsClaimed(address indexed staker, uint256 claimedAmount);

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
        nextRedeemTime = block.timestamp;
        devFundAddress = __owner;
        deploymentBlockTime = block.timestamp;

        // 1 eth = 1500000 genius => 1 genius = 1/(1500000) eth 
        // => 1 genius = 1/1500000  * 10 ** 18 wei
        // => 1000 * 10**6 genius = 1000 * 10**6/1500000 wei = 667 wei
        startPrice = 666666666667; // wei 
    }
    

   function _transfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20)
        nonReentrant
    {
        require(!blacklist[from], "Error: blacklist from");
        require(!blacklist[to], "Error: blacklist to");
        require(!isLocked(from), "Error: address is locked 24 hours after buying");

        if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            super._transfer(from, to, amount);
        } else {
            if(hasRole(NOT_TAXED_FROM, from) || hasRole(NOT_TAXED_TO, to) || !taxed()) {
                super._transfer(from, to, amount);
            } else { 
                require(balanceOf(from) >= amount, "Error: transfer amount exceeds balance");
                super._transfer(from, taxdestination(), amount*thetax()/10000); 
                super._transfer(from, to, amount*(10000-thetax())/10000);
            }
        }
    }
    

    // lock tokens for 24 hours
    function lock() public {
        lockTimestamps[msg.sender] = block.timestamp + 24 hours;
    }
    

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");        
        
        require(transfer(address(this), amount), "Token transfer failed");
        claimEarnings();

        User storage user = users[msg.sender];
        user.stakedAmount += amount;
        user.lastClaimTime = block.timestamp;
        totalStakedAmount += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        User storage user = users[msg.sender];
        require(user.stakedAmount >= amount, "Not enough funds to unstake");
        claimEarnings();

        user.stakedAmount -= amount;
        totalStakedAmount -= amount;
        _transfer(address(this), address(msg.sender), amount);

        emit Unstaked(msg.sender, amount);
    }
    

    function claimEarnings() public {
        User storage user = users[msg.sender];

        uint256 earnedAmount = claimableEarnings(msg.sender);        
        if (earnedAmount > 0) {            
        
            user.earnedAmount += earnedAmount;
            user.lastClaimTime = block.timestamp;
            _mint(msg.sender, earnedAmount);

            emit EarningsClaimed(msg.sender, earnedAmount);
        }
    }
    

    function burn(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "Error: not enough balance to burn");
        _burn(msg.sender, _amount);
    }    


    // function to buy tokens
    function buy( address referral) public payable {
        require(buyingEnabled, "Error: buyingEnabled is False");
        
        uint256 _ethAmount = msg.value; // wei
        require(_ethAmount>0, "Incorrect ETH amount");
        
        // calculate the number of tokens to be minted
        uint256 price = getCurrentPrice(); // price in wei for 1 billion tokens
        require(price > 0, "Price should not be 0");
        uint256 tokens = _ethAmount / price * 10 ** decimals();


        // mint tokens
        _mint(msg.sender, tokens);

        // lock for 24 hours
        lock();

        // check if _ethAmount is more than 0.01 ETH
        if (_ethAmount >= 0.01 ether) {
            // airdrop for lucky buyers
            buyers.push(msg.sender);

            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp))) % buyers.length;
            address luckyBuyer = buyers[randomIndex];
            _mint(luckyBuyer, tokens/100 ); //  1% airdrop 
        }

        // transfer 1% to referral
        if (referral != address(0) && referral != msg.sender) {
            _mint(referral, tokens/100 ); // 1% referral
        }
        
    }



    //////////////////////////
    // OPEATOR FUNCTIONS
    //////////////////////////
    // Airdrop function: the ability to distribute tokens to multiple addresses at once with the random amount of tokens (capped)
    function airdrop(address[] memory _addresses, uint _amount) public onlyRole(OPERATOR_ROLE) {
        require(_addresses.length <= 255, "Error: too many addresses");
        require(_amount <= 1000);
        for (uint8 i = 0; i < _addresses.length; i++) {
            uint _random = uint(keccak256(abi.encodePacked(block.timestamp, block.number, i))) % _amount * 10 ** decimals();

            if (airdroppedUsers[_addresses[i]] == false) {                
                _mint(_addresses[i], _random);
                airdroppedUsers[_addresses[i]] = true;
            }
            
        }
    }
    
    

     //////////////////////////
    // ADMIN REQUIRED FUNCTIONS
    //////////////////////////
    function withdrawErc20(address tokenAddress, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        IERC20 _tokenInstance = IERC20(tokenAddress);
        _tokenInstance.transfer(msg.sender, amount * 10**18);
    }

    function emergencyETHWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE)  {
        (bool sent, ) = (address(msg.sender)).call{
            value: address(this).balance
        }("");
        require(sent, "Error: Cannot withdraw");
    }


    function blacklistAddress(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(!blacklist[_address], "Address is already blacklisted");
        blacklist[_address] = true;
    }

    function unblacklistAddress(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(blacklist[_address], "Address is not blacklisted");
        blacklist[_address] = false;
    }

    
    // Token Redemptions: for the ability to mint a specific amount of tokens to a predefined address (which can be changed)
    // each month, 1 millions token is minted to the address
    // a timer is set each time the function is called, after called, timer is set to next 30 days
    // the amount of tokens can be claimed is reduced by 1% each month

    function devFundRedeem() public onlyRole(DEFAULT_ADMIN_ROLE) {
        // required devFundEnabled = true
        require(devFundEnabled, "Error: devFundEnabled is false");
        require(block.timestamp >= nextRedeemTime, "Error: redeem time not reached");
        // required monthlyDevFund > 0
        require(monthlyDevFund > 0, "Error: monthlyDevFund is 0");
        nextRedeemTime = block.timestamp + 30 days;
        _mint(devFundAddress, monthlyDevFund);
        monthlyDevFund = monthlyDevFund * 99 / 100;
    }

    
    // set startPrice
    function setStartPrice(uint256 _startPrice) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // eth wei price per 1000000 (1 million) Genius (10** 18)
        require(_startPrice > 0, "Error: startPrice should be greater than 0");
        startPrice = _startPrice;
    }

    // update buyingEnabled only by admin
    function updateBuyingEnabled(bool _buyingEnabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        buyingEnabled = _buyingEnabled;
    }
    // update devFundEnabled only by admin
    function updateDevFundEnabled(bool _devFundEnabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        devFundEnabled = _devFundEnabled;
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
     function updateDevFundDestination(address newdestination) public onlyRole(DEFAULT_ADMIN_ROLE) {
        devFundAddress = newdestination; 
    }


    //////////////////////////
    // view only functions
    //////////////////////////

    function isBlacklisted(address _address) public view returns (bool) {
        return blacklist[_address];
    }

     // function to check if tokens are locked
    function isLocked(address _owner) public view returns (bool) {
        return lockTimestamps[_owner] > block.timestamp;
    }
    // function to check when an address can unlock tokens
    function unlockTime(address _owner) public view returns (uint256) {
        return lockTimestamps[_owner];
    }

    function currentAPY() public view returns (uint256) {
        uint256 monthsSinceDeploy = (block.timestamp - deploymentBlockTime) / 30 days;
        uint256 apy = INITIAL_APY - MONTHLY_APY_DECREASE * monthsSinceDeploy;
        return apy < MIN_APY ? MIN_APY : apy;
    }
    function claimableEarnings(address staker) public view returns (uint256) {
        User storage user = users[staker];

        uint256 elapsedTime = block.timestamp - user.lastClaimTime;
        uint256 earnedAmount = (user.stakedAmount * elapsedTime * this.currentAPY()) / (365 days * 100);

        return earnedAmount;
    }

    // get current Price of the token
    function getCurrentPrice() public view returns (uint256) {
        uint256 weeksSinceDeploy = (block.timestamp - deploymentBlockTime) / (7 days);
        return startPrice * (1 + (weeksSinceDeploy / 100)); // 1% increase each week
    }

}
