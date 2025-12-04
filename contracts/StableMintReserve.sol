// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title StableMint Reserve
 * @notice A collateral-backed stablecoin minting system where users deposit ETH to mint stable tokens.
 *         Tokens can later be burned to redeem collateral, maintaining reserve backing at all times.
 */

contract StableMintReserve {
    
    string public name = "StableMint Reserve Token";
    string public symbol = "SMRT";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateral ratio for safety

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Tracks collateral deposits for each user
    mapping(address => uint256) public collateralDeposited;

    address public owner;

    event Mint(address indexed user, uint256 collateralAmount, uint256 tokenAmount);
    event Burn(address indexed user, uint256 tokenAmount, uint256 collateralReturned);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Restricted to owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Deposit ETH to mint SMRT stable tokens
     */
    function mint() external payable {
        require(msg.value > 0, "Deposit required");

        uint256 tokenAmount = (msg.value * 100) / COLLATERAL_RATIO; // mint less than collateral to maintain backing
        collateralDeposited[msg.sender] += msg.value;
        totalSupply += tokenAmount;
        balanceOf[msg.sender] += tokenAmount;

        emit Mint(msg.sender, msg.value, tokenAmount);
    }

    /**
     * @notice Burn SMRT tokens and redeem collateral
     */
    function burn(uint256 tokenAmount) external {
        require(balanceOf[msg.sender] >= tokenAmount, "Not enough tokens");

        uint256 collateralToReturn = (tokenAmount * COLLATERAL_RATIO) / 100;
        require(collateralDeposited[msg.sender] >= collateralToReturn, "Insufficient collateral");

        balanceOf[msg.sender] -= tokenAmount;
        totalSupply -= tokenAmount;
        collateralDeposited[msg.sender] -= collateralToReturn;

        payable(msg.sender).transfer(collateralToReturn);

        emit Burn(msg.sender, tokenAmount, collateralToReturn);
    }

    /**
     * @notice Standard ERC-20 transfer
     */
    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Approve tokens for spending
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens using allowance (ERC-20)
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @notice Get value of user's collateral reserve
     */
    function getCollateral(address user) external view returns (uint256) {
        return collateralDeposited[user];
    }
}
