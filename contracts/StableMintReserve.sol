e.g., USDC, DAI, ETH wrapper
    StableMintToken public smr;      150% overcollateralization
    uint256 public mintFeeBps = 20;  0.05%

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

        Check collateral ratio
        require(_isValidMint(p, amount), "Insufficient collateral");

        p.mintedSMR += amount;

        smr.mint(msg.sender, netAmount);
        smr.mint(owner, fee); Fee
        uint256 fee = (amount * burnFeeBps) / PRECISION;
        uint256 netBurn = amount - fee;

        smr.burn(msg.sender, netBurn);
        smr.burn(msg.sender, fee); Must remain overcollateralized
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
// 
Contract End
// 
