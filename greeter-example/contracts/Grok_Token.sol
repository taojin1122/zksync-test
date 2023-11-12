/**
 *Submitted for verification at Etherscan.io on 2023-11-04
*/

/*

https://t.me/GROKERC20

*/
// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

// 抽象的合约对象
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval (address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}
// 所有者合约对象 
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
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
}

contract GROK is Context, IERC20, Ownable {
    using SafeMath for uint256;
    // 存储地址对应的余额
    mapping (address => uint256) private _balances;
    // 存储授权信息，用户代币转账
    mapping (address => mapping (address => uint256)) private _allowances;
    // 用户标记不收取费用的地址
    mapping (address => bool) private _isExcludedFromFee;
    // 存储被标记人机器人的地址
    mapping (address => bool) private bots;
    //  存储税金收取的地址
    address payable private _taxWallet;
    // 记录合约创建时的区块号
    uint256 firstBlock;
    // 初始的购买税率
    uint256 private _initialBuyTax=24;
    // 初始的卖出税率
    uint256 private _initialSellTax=24;
    // 最终的购买税率
    uint256 private _finalBuyTax=0;
    // 最终的卖出税率
    uint256 private _finalSellTax=0;
    // 在达到一定买入次数后减少税率的点
    uint256 private _reduceBuyTaxAt=19;
    // 在达到一定卖出次数后减少税率的点
    uint256 private _reduceSellTaxAt=29;
    // 在达到一定次数前禁止交换。
    uint256 private _preventSwapBefore=20;
    // 记录购买次数，用户计算税率
    uint256 private _buyCount=0;
    // 代币的小数位
    uint8 private constant _decimals = 9;
    // 代币的总供应量
    uint256 private constant _tTotal = 6900000000 * 10**_decimals;
    string private constant _name = unicode"GROK";
    string private constant _symbol = unicode"GROK";
    // 限制每个单独的交易中能够转移的最大代币数量。
    uint256 public _maxTxAmount = 138000000 * 10**_decimals;
    //限制每个钱包地址能够持有的最大代币数量。
    uint256 public _maxWalletSize = 138000000 * 10**_decimals;
    // 当合约中的代币余额超过这个阈值时，触发自动进行代币和 ETH 的交换。
    uint256 public _taxSwapThreshold= 69000000 * 10**_decimals;
    //限制每次交换的最大代币数量。
    uint256 public _maxTaxSwap= 69000000 * 10**_decimals;

     // Uniswap V2 路由合约地址
    IUniswapV2Router02 private uniswapV2Router;
    // Uniswap V2 交易对地址。
    address private uniswapV2Pair;
    //  标志是否开放交易
    bool private tradingOpen;
    // 标志是否正在进行交换
    bool private inSwap = false;
    // 标志是否启用自动交换。
    bool private swapEnabled = false;

    // 当最大交易金额更新时触发。
    event MaxTxAmountUpdated(uint _maxTxAmount);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () {

        _taxWallet = payable(_msgSender());
        _balances[_msgSender()] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    // 用户执行代币转账，并处理税金，交换等逻辑
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        // 如果转出地址和接收地址均不是合约创建者（owner()），
        // 并且这两个地址都没有被标记为机器人地址，就会计算税金。
        // 并且会将合约中的 币卖出为 eth
        if (from != owner() && to != owner()) {
            // 并且这个地址没有被标记为机器人地址
            require(!bots[from] && !bots[to]);
            // 计算税金 mul 是 SafeMath 库的一个函数，用于安全地执行乘法操作，以防止溢出或下溢。

            // 这种设计的目的可能是在一定条件下，例如购买次数达到一定数量后，逐步减小购买的税率。
            // 税率以百分比的形式表示，因此需要除以 100 转换为小数。
            taxAmount = amount.mul((_buyCount>_reduceBuyTaxAt)?_finalBuyTax:_initialBuyTax).div(100);
            // from 是交易对地址判定为买入
            if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to] ) {
                // 每次转移数量限制
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");

                if (firstBlock + 3  > block.number) {
                    require(!isContract(to));
                }
                _buyCount++;
            }
            // 转移的接收地址，判断一下他的钱包余额是否超出了
            if (to != uniswapV2Pair && ! _isExcludedFromFee[to]) {
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
            }
            // to 如果是交易对地址 判断为卖出   
            if(to == uniswapV2Pair && from!= address(this) ){
                taxAmount = amount.mul((_buyCount>_reduceSellTaxAt)?_finalSellTax:_initialSellTax).div(100);
            }
            // 合约 余额
            uint256 contractTokenBalance = balanceOf(address(this));
            // 如果以上条件均满足，并且没有处于交换状态 inSwap，启用了自动交换 swapEnabled，
            // 且合约余额大于设定的自动交换阈值 _taxSwapThreshold 且购买次数 _buyCount 大于设定的禁止交换前次数
            //  _preventSwapBefore，则进行代币交换操作，并将交换后的 ETH 发送到税金收取地址。
            if (!inSwap && to   == uniswapV2Pair && swapEnabled && contractTokenBalance>_taxSwapThreshold && _buyCount>_preventSwapBefore) {
                
                swapTokensForEth(min(amount,min(contractTokenBalance,_maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if(contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }
        // 如果税金 大于0 
        if(taxAmount>0){
            // 合约地址中代币数量增加
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        // 转出地址 数量减少
        _balances[from]=_balances[from].sub(amount);
        // 接收地址 数量增加 并且减少相应的税金
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }


    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    // 修饰器 
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        // 授权 将合约的数量，授权给 路由
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner{
        _maxTxAmount = _tTotal;
        _maxWalletSize=_tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }
    // 将合约中的 eth 转移给 税金地址 
    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function addBots(address[] memory bots_) public onlyOwner {
        for (uint i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function delBots(address[] memory notbot) public onlyOwner {
      for (uint i = 0; i < notbot.length; i++) {
          bots[notbot[i]] = false;
      }
    }

    function isBot(address a) public view returns (bool){
      return bots[a];
    }
    // 开启交易的函数 只有合约创建者可以调用
    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        // 将 Uniswap V2 路由合约的地址指定给 uniswapV2Router 变量。这里使用了固定的 Uniswap V2 路由地址
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        // 使用 _approve 函数为合约自身授权总供应量 _tTotal 的代币数量给 Uniswap V2 路由合约。
        _approve(address(this), address(uniswapV2Router), _tTotal);
        // 创建交易对
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        // 创建流动性
        // 向 Uniswap V2 交易对中添加代币和 ETH 的流动性。
        // value: address(this).balance 表示将合约当前的 ETH 余额作为价值传递给 addLiquidityETH 函数。

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        // 使用 IERC20 接口为 Uniswap V2 路由合约授权无限数量的代币，以确保 Uniswap 在后续交易中可以无限制地使用代币。
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        swapEnabled = true;
        tradingOpen = true;
        firstBlock = block.number;
    }
    // 定义这个合约 接收 以太坊支付  如果没有 payable 关键字，合约将无法接收以太币。
    receive() external payable {}

}