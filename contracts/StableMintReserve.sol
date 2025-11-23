// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title StableMint Reserve
 * @dev A decentralized stablecoin system with collateral management
 * @notice This contract manages minting, burning, and collateral for a USD-pegged stablecoin
 */
contract StableMintReserve {
    
    // State Variables
    string public name = "StableMint USD";
    string public symbol = "SMUSD";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public collateralRatio = 150; // 150% collateralization required
    uint256 public constant PRECISION = 100;
    
    address public owner;
    bool public paused;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public collateralDeposits;
    mapping(address => uint256) public mintedAmount;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed user, uint256 amount, uint256 collateral);
    event Burn(address indexed user, uint256 amount, uint256 collateralReturned);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralRatioUpdated(uint256 newRatio);
    event Paused(bool status);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Function 1: Deposit collateral (ETH) into the reserve
     */
    function depositCollateral() external payable whenNotPaused {
        require(msg.value > 0, "Must deposit collateral");
        collateralDeposits[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Function 2: Mint stablecoins based on deposited collateral
     * @param amount Amount of stablecoins to mint
     */
    function mintStablecoin(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 requiredCollateral = (amount * collateralRatio) / PRECISION;
        uint256 availableCollateral = collateralDeposits[msg.sender] - mintedAmount[msg.sender];
        
        require(availableCollateral >= requiredCollateral, "Insufficient collateral");
        
        mintedAmount[msg.sender] += amount;
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        
        emit Mint(msg.sender, amount, requiredCollateral);
        emit Transfer(address(0), msg.sender, amount);
    }
    
    /**
     * @dev Function 3: Burn stablecoins to unlock collateral
     * @param amount Amount of stablecoins to burn
     */
    function burnStablecoin(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        require(mintedAmount[msg.sender] >= amount, "Cannot burn more than minted");
        
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        mintedAmount[msg.sender] -= amount;
        
        emit Burn(msg.sender, amount, 0);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    /**
     * @dev Function 4: Withdraw collateral after burning stablecoins
     * @param amount Amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 lockedCollateral = (mintedAmount[msg.sender] * collateralRatio) / PRECISION;
        uint256 availableCollateral = collateralDeposits[msg.sender] - lockedCollateral;
        
        require(availableCollateral >= amount, "Insufficient available collateral");
        
        collateralDeposits[msg.sender] -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit CollateralWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Function 5: Transfer stablecoins between addresses
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Function 6: Approve spender to use tokens
     * @param spender Address to approve
     * @param amount Amount to approve
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "Invalid address");
        
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Function 7: Transfer tokens on behalf of another address
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transferFrom(address from, address to, uint256 amount) 
        external 
        whenNotPaused 
        returns (bool) 
    {
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Function 8: Check user's collateralization health
     * @param user Address to check
     */
    function getCollateralizationRatio(address user) external view returns (uint256) {
        if (mintedAmount[user] == 0) return 0;
        return (collateralDeposits[user] * PRECISION) / mintedAmount[user];
    }
    
    /**
     * @dev Function 9: Update collateral ratio requirement (only owner)
     * @param newRatio New collateral ratio (e.g., 150 for 150%)
     */
    function updateCollateralRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 100, "Ratio must be at least 100%");
        require(newRatio <= 300, "Ratio too high");
        
        collateralRatio = newRatio;
        emit CollateralRatioUpdated(newRatio);
    }
    
    /**
     * @dev Function 10: Pause/unpause contract (only owner)
     * @param status True to pause, false to unpause
     */
    function setPaused(bool status) external onlyOwner {
        paused = status;
        emit Paused(status);
    }
    
    // View functions
    function getAvailableCollateral(address user) external view returns (uint256) {
        uint256 lockedCollateral = (mintedAmount[user] * collateralRatio) / PRECISION;
        if (collateralDeposits[user] <= lockedCollateral) return 0;
        return collateralDeposits[user] - lockedCollateral;
    }
    
    function getLockedCollateral(address user) external view returns (uint256) {
        return (mintedAmount[user] * collateralRatio) / PRECISION;
    }
    
    // Fallback function to receive ETH
    receive() external payable {
        collateralDeposits[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }
}