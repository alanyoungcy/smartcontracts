// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}

contract WETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8  public decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint256) public  balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    event  Approval(address indexed owner, address indexed spender, uint256 value);
    event  Transfer(address indexed from, address indexed to, uint256 value);
    event  Deposit(address indexed dst, uint256 wad);
    event  Withdrawal(address indexed src, uint256 wad);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        totalSupply -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }
    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint256 wad) public returns (bool)
    {
        require(balanceOf[src] >= wad, "WETH: insufficient balance");

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "WETH: insufficient allowance");
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}

contract SimpleAMM {
    IERC20 public token; // 另一种 ERC20 代币
    WETH public weth;

    uint256 public reserveToken;
    uint256 public reserveWETH;

    event Swap(address indexed sender, uint amountInToken, uint amountInWETH);
    event AddLiquidity(address indexed provider, uint amountToken, uint amountWETH);
    event RemoveLiquidity(address indexed provider, uint amountToken, uint amountWETH);

    constructor(IERC20 _token, WETH _weth) {
        token = _token;
        weth = _weth;
    }

    // 添加流动性
    function addLiquidity(uint amountToken, uint amountWETH) external {
        require(token.transferFrom(msg.sender, address(this), amountToken), "Transfer failed");
        require(weth.transferFrom(msg.sender, address(this), amountWETH), "Transfer failed");

        reserveToken += amountToken;
        reserveWETH += amountWETH;

        emit AddLiquidity(msg.sender, amountToken, amountWETH);
    }

    // 移除流动性
    function removeLiquidity(uint amountToken, uint amountWETH) external {
        require(reserveToken >= amountToken && reserveWETH >= amountWETH, "Insufficient reserves");

        reserveToken -= amountToken;
        reserveWETH -= amountWETH;

        require(token.transfer(msg.sender, amountToken), "Transfer failed");
        require(weth.transfer(msg.sender, amountWETH), "Transfer failed");

        emit RemoveLiquidity(msg.sender, amountToken, amountWETH);
    }

    // 交换 Token 到 WETH
    function swapTokenForWETH(uint amountTokenIn) external {
        require(token.transferFrom(msg.sender, address(this), amountTokenIn), "Transfer failed");

        uint amountWETHOut = getAmountOut(amountTokenIn, reserveToken, reserveWETH);

        reserveToken += amountTokenIn;
        reserveWETH -= amountWETHOut;

        require(weth.transfer(msg.sender, amountWETHOut), "Transfer failed");

        emit Swap(msg.sender, amountTokenIn, amountWETHOut);
    }

    // 交换 WETH 到 Token
    function swapWETHForToken(uint amountWETHIn) external {
        require(weth.transferFrom(msg.sender, address(this), amountWETHIn), "Transfer failed");

        uint amountTokenOut = getAmountOut(amountWETHIn, reserveWETH, reserveToken);

        reserveWETH += amountWETHIn;
        reserveToken -= amountTokenOut;

        require(token.transfer(msg.sender, amountTokenOut), "Transfer failed");

        emit Swap(msg.sender, amountTokenOut, amountWETHIn);
    }

    // 根据常数乘积公式计算输出数量
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint amountInWithFee = amountIn * 997; // 考虑 0.3% 费用
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;

        amountOut = numerator / denominator;
    }
}