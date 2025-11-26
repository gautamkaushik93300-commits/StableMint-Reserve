State Variables
    string public name = "StableMint USD";
    string public symbol = "SMUSD";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public collateralRatio = 150; Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed user, uint256 amount, uint256 collateral);
    event Burn(address indexed user, uint256 amount, uint256 collateralReturned);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralRatioUpdated(uint256 newRatio);
    event Paused(bool status);
    
    View functions
    function getAvailableCollateral(address user) external view returns (uint256) {
        uint256 lockedCollateral = (mintedAmount[user] * collateralRatio) / PRECISION;
        if (collateralDeposits[user] <= lockedCollateral) return 0;
        return collateralDeposits[user] - lockedCollateral;
    }
    
    function getLockedCollateral(address user) external view returns (uint256) {
        return (mintedAmount[user] * collateralRatio) / PRECISION;
    }
    
    End
End
// 
// 
End
// 
