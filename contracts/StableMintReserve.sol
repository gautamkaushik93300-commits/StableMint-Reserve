// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title StableMint Reserve
 * @notice A simple overcollateralized stablecoin protocol:
 *         - Deposit collateral
 *         - Mint SMR stablecoin
 *         - Burn SMR to withdraw collateral
 * @dev Add oracles, liquidation protection, audits for production.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function transfer(address to, uint256 val) external returns (bool);
    function transferFrom(address from, address to, uint256 val) external returns (bool);
}

/* --------------------------------------------------------------
   Minimal ERC20 Stablecoin (SMR)
----------------------------------------------------------------*/
contract StableMintToken {
    string public name = "StableMint Reserve";
    string public symbol = "SMR";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    address public controller;

    mapping(address => uint256) public balanceOf;

    modifier onlyController() {
        require(msg.sender == controller, "Not controller");
        _;
    }

    constructor(address _controller) {
        controller = _controller;
    }

    function mint(address to, uint256 amount) external onlyController {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external onlyController {
        require(balanceOf[from] >= amount, "Not enough SMR");
        totalSupply -= amount;
        balanceOf[from] -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Balance low");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/* --------------------------------------------------------------
   StableMint Reserve Main Contract
----------------------------------------------------------------*/
contract StableMintReserve {
    IERC20 public collateral;        // e.g., USDC, DAI, ETH wrapper
    StableMintToken public smr;      // stablecoin token

    address public owner;

    uint256 public constant PRECISION = 1e5;
    uint256 public minCollateralRatio = 150_000; // 150% overcollateralization
    uint256 public mintFeeBps = 20;  // 0.20%
    uint256 public burnFeeBps = 5;   // 0.05%

    struct Position {
        uint256 collateralAmount;
        uint256 mintedSMR;
    }

    mapping(address => Position) public positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event SMRMinted(address indexed user, uint256 amount, uint256 fee);
    event SMRBurned(address indexed user, uint256 amount, uint256 fee);
    event CollateralWithdrawn(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _collateral) {
        collateral = IERC20(_collateral);
        smr = new StableMintToken(address(this));
        owner = msg.sender;
    }

    /* --------------------------------------------------------------
       DEPOSIT COLLATERAL
    --------------------------------------------------------------*/
    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Zero amount");

        collateral.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateralAmount += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    /* --------------------------------------------------------------
       MINT SMR AGAINST COLLATERAL
    --------------------------------------------------------------*/
    function mintSMR(uint256 amount) external {
        require(amount > 0, "Zero mint");

        Position storage p = positions[msg.sender];

        // Fee
        uint256 fee = (amount * mintFeeBps) / PRECISION;
        uint256 netAmount = amount - fee;

        // Check collateral ratio
        require(_isValidMint(p, amount), "Insufficient collateral");

        p.mintedSMR += amount;

        smr.mint(msg.sender, netAmount);
        smr.mint(owner, fee); // protocol fee

        emit SMRMinted(msg.sender, amount, fee);
    }

    function _isValidMint(Position memory p, uint256 mintAmount)
        internal
        view
        returns (bool)
    {
        uint256 newDebt = p.mintedSMR + mintAmount;
        return p.collateralAmount * PRECISION / newDebt >= minCollateralRatio;
    }

    /* --------------------------------------------------------------
       BURN SMR TO REDEEM COLLATERAL
    --------------------------------------------------------------*/
    function burnSMR(uint256 amount) external {
        require(amount > 0, "Zero amount");

        Position storage p = positions[msg.sender];
        require(p.mintedSMR >= amount, "Too much burn");

        // Fee
        uint256 fee = (amount * burnFeeBps) / PRECISION;
        uint256 netBurn = amount - fee;

        smr.burn(msg.sender, netBurn);
        smr.burn(msg.sender, fee); // burn fee stays removed

        p.mintedSMR -= amount;

        emit SMRBurned(msg.sender, amount, fee);
    }

    /* --------------------------------------------------------------
       WITHDRAW COLLATERAL
    --------------------------------------------------------------*/
    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "Zero amount");

        Position storage p = positions[msg.sender];
        require(p.collateralAmount >= amount, "Too much withdraw");

        // Must remain overcollateralized
        require(
            _isAboveCollateralRatio(
                p.collateralAmount - amount,
                p.mintedSMR
            ),
            "Below collateral ratio"
        );

        p.collateralAmount -= amount;
        collateral.transfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function _isAboveCollateralRatio(uint256 collateralAmt, uint256 debt)
        internal
        view
        returns (bool)
    {
        if (debt == 0) return true;
        uint256 ratio = collateralAmt * PRECISION / debt;
        return ratio >= minCollateralRatio;
    }

    /* --------------------------------------------------------------
       ADMIN
    --------------------------------------------------------------*/
    function setCollateralRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 120_000, "Ratio too low");
        minCollateralRatio = newRatio;
    }

    function setFees(uint256 _mintFeeBps, uint256 _burnFeeBps) external onlyOwner {
        require(_mintFeeBps <= 200, "Too high");
        require(_burnFeeBps <= 200, "Too high");
        mintFeeBps = _mintFeeBps;
        burnFeeBps = _burnFeeBps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
