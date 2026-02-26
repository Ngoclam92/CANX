// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
CANXO — Canopy Expansion
Deflationary + Auto Liquidity + BNB Reward Pool
*/

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

interface IPancakeRouter02 {
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

contract CANXO is IERC20 {

    string public name = "Canopy Expansion";
    string public symbol = "CANXO";
    uint8 public decimals = 18;

    uint256 private _totalSupply = 1_000_000_000 * 1e18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    // Fees
    uint256 public burnFee = 2;
    uint256 public liquidityFee = 2;
    uint256 public rewardFee = 2;
    uint256 private constant FEE_DENOM = 100;

    // Limits
    uint256 public maxWallet;
    bool public limitsEnabled = true;

    // Router
    IPancakeRouter02 public router;
    address public pair;

    bool private inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor(address _router) {
        owner = msg.sender;
        router = IPancakeRouter02(_router);

        _balances[msg.sender] = _totalSupply;
        maxWallet = _totalSupply / 50; // 2%
    }

    receive() external payable {}

    // IERC20
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender,address recipient,uint256 amount) external override returns (bool) {
        _allowances[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(_balances[from] >= amount, "Insufficient balance");

        if(limitsEnabled && to != address(0)) {
            require(_balances[to] + amount <= maxWallet, "Max wallet exceeded");
        }

        uint256 burnAmount = amount * burnFee / FEE_DENOM;
        uint256 liquidityAmount = amount * liquidityFee / FEE_DENOM;
        uint256 rewardAmount = amount * rewardFee / FEE_DENOM;

        uint256 sendAmount = amount - burnAmount - liquidityAmount - rewardAmount;

        _balances[from] -= amount;
        _balances[to] += sendAmount;

        // Burn
        _totalSupply -= burnAmount;

        // Contract collects liquidity + reward
        _balances[address(this)] += liquidityAmount + rewardAmount;

        if(!inSwap && from != address(this)) {
            _swapBack();
        }
    }

    function _swapBack() internal swapping {
        uint256 contractBalance = _balances[address(this)];
        if(contractBalance == 0) return;

        address;
        path[0] = address(this);
        path[1] = router.WETH();

        _allowances[address(this)][address(router)] = contractBalance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    // Admin
    function setFees(uint256 _burn, uint256 _liq, uint256 _reward) external onlyOwner {
        require(_burn + _liq + _reward <= 10, "Too high");
        burnFee = _burn;
        liquidityFee = _liq;
        rewardFee = _reward;
    }

    function setMaxWallet(uint256 amount) external onlyOwner {
        maxWallet = amount;
    }

    function disableLimits() external onlyOwner {
        limitsEnabled = false;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }
}

