// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
CANX — Canopy Next
Deflationary + Profit Sharing Token
*/

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

interface IPancakeRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract CANX is IERC20 {

    string public name = "Canopy Next";
    string public symbol = "CANX";
    uint8 public decimals = 18;

    uint256 public override totalSupply = 1_000_000_000 * 1e18;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner); _; }

    // Fees
    uint256 public burnFee = 2;
    uint256 public rewardFee = 3;
    uint256 public liquidityFee = 1;
    uint256 public constant FEE_DENOM = 100;

    // Anti whale
    uint256 public maxWallet = totalSupply / 50; // 2%
    bool public limitsEnabled = true;

    // Pancake
    IPancakeRouter public router;
    address public pair;

    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    // Dividend
    mapping(address => uint256) public rewards;

    constructor(address _router) {
        owner = msg.sender;
        router = IPancakeRouter(_router);
        balanceOf[msg.sender] = totalSupply;
    }

    receive() external payable {}

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from,address to,uint256 amount) public override returns (bool) {
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "No balance");

        if(limitsEnabled && to != pair && to != address(0)) {
            require(balanceOf[to] + amount <= maxWallet, "Max wallet");
        }

        uint256 burnAmount = amount * burnFee / FEE_DENOM;
        uint256 rewardAmount = amount * rewardFee / FEE_DENOM;
        uint256 liquidityAmount = amount * liquidityFee / FEE_DENOM;

        uint256 sendAmount = amount - burnAmount - rewardAmount - liquidityAmount;

        balanceOf[from] -= amount;
        balanceOf[to] += sendAmount;

        // Burn
        totalSupply -= burnAmount;

        // Contract holds fees
        balanceOf[address(this)] += rewardAmount + liquidityAmount;

        if(!inSwap && from != pair) {
            _swapAndDistribute();
        }
    }

    function _swapAndDistribute() internal swapping {
        uint256 contractBal = balanceOf[address(this)];
        if(contractBal == 0) return;

        address;
        path[0] = address(this);
        path[1] = router.WETH();

        allowance[address(this)][address(router)] = contractBal;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractBal,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 ethBal = address(this).balance;
        if(ethBal > 0) {
            rewards[owner] += ethBal;
        }
    }

    function claimRewards() external {
        uint256 amount = rewards[msg.sender];
        require(amount > 0);
        rewards[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // Admin
    function setFees(uint256 _burn, uint256 _reward, uint256 _liq) external onlyOwner {
        burnFee = _burn;
        rewardFee = _reward;
        liquidityFee = _liq;
    }

    function setMaxWallet(uint256 _amount) external onlyOwner {
        maxWallet = _amount;
    }

    function disableLimits() external onlyOwner {
        limitsEnabled = false;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }
}
