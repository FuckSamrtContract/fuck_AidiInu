
pragma solidity ^0.8.0;

/*
 *定义接口，通过_msgSender，和_msgData获取合约的调用地址以及调用时候的数据。
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * ERC20 标准接口
 */
interface IERC20 {
    /**
     * 代币的总量.
     */
    function totalSupply() external view returns (uint256);

    /**
     * 指定地址拥有Aidi币的数量.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * 向接收地址转一定的数量的Aidi币
     * 当成功转移token时，一定要触发Transfer事件
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * 返回spender还能调用owner地址下Aidi币的数量
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * 批准_spender账户从调用者的账户转移amount个Aidi币。可以分多次转移。
     * 与transferFrom搭配使用，approve批准之后，调用transferFrom函数来转移token
     * 当调用approval函数成功时，一定要触发Approval事件
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * 从sender转移amount个aidi币到recipient
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * 事件
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * 事件
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * 主要返回AidiInu的简要信息
 */
interface IERC20Metadata is IERC20 {
    /**
     * 代币名称.
     */
    function name() external view returns (string memory);

    /**
     * 代币symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * 代币精度.
     */
    function decimals() external view returns (uint8);
}


/**
 * 默认情况下，合约由部署者所有，但AidiInu在后期可以改变合约的所有者，像白皮书书写的那样，放弃合约的所有权
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * 最开始在部署合约时候，合约由部署者所有.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * 当前合约的所有者
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * 若其他account调用，则返回“Ownable: caller is not the owner”信息
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * 将合约的所有者转给黑洞地址，配合transferOwnership使用。
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0); #0x0000000000000000000000000000000000000000
    }

    /**
     * 将合约的所有者转给黑洞地址
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract AidiInu is Context, IERC20, IERC20Metadata, Ownable {
    
    mapping (address => uint256) private _rOwned;                                    # realOwned 实际拥有
    mapping (address => uint256) private _tOwned;                                    # 初始拥有
    mapping (address => mapping (address => uint256)) private _allowances;           # 可使用的aidi币

    mapping (address => bool) private _isExcluded;                                   # 是否是排除地址
    address[] private _excluded;                                                     # 排除地址合集
   
    uint256 private constant MAX = ~uint256(0);                                      # 
    uint256 private constant _tTotal = 100000000000 * 10**6 * 10**9;                 # Aidi发行的总量  **是幂运算  10**9(1亿),10**6(100万),100000000000(1000亿)
    uint256 private _rTotal = (MAX - (MAX % _tTotal));                               # 因为_decimals为9，所以实际_tTotal为：10000万亿个Aidi币
    uint256 private _tFeeTotal;                                                      # 通过交易产生的手续费总额

    string private _name = 'Aidi Inu';
    string private _symbol = 'AIDI';
    uint8 private _decimals = 9;
                                  
    uint256 public _maxTxAmount = 100000000 * 10**6 * 10**9;                       # 单笔最大交易数量，初始值是总供应量的1/1000

    constructor () {
        _rOwned[_msgSender()] = _rTotal;                                           # 合约创建时候，直接将10000万亿个Aidi币给合约创建者
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];                          # 合约调用者有多少个Aidi币
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);                                 # 从合约调用者_msgSender，转移amount个aidi币到recipient地址
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];                                         # spender能使用owner下多少Aidi币
     }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);                                       # 最重要的transfer函数
        require(amount <= _allowances[sender][_msgSender()], "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()]- amount);
        return true;
    }
  
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(subtractedValue <= _allowances[_msgSender()][spender], "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }
    
    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }
    
    
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = ((_tTotal * maxTxPercent) / 10**2);
    }

    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return (rAmount / currentRate);
    }

    function excludeAccount(address account) external onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");             # 不能授权使用 销毁地址的币
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");           # address(0)黑洞地址不能进行交易
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        if(sender != owner() && recipient != owner()) {
          require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");    # 除合约拥有者，交易量不能大约发行量的1/1000，限制巨额交易？
        }
            
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }
    ## 标准交易函数
    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);   # tAmount 是发起交易时的币量
        _rOwned[sender] = _rOwned[sender] - rAmount;                                                                             # 发送方实际交易中减少的币量是rAmount？
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;                                                               # 接收方实际交易中增加的的币量是rAmount？
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;           
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;   
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);                                     # 将要交易的币分为2部分，tTransferAmount和tFee，tFee其实就是返现给持币者的
        uint256 currentRate =  _getRate();                                                                  # 现存币量占发行币量的比例
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate); # 
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);                                     # 
    }

    function _getTValues(uint256 tAmount) private pure returns (uint256, uint256) {
        uint256 tFee = ((tAmount / 100) * 2);                                                               # 将tTransferAmount扣除%2的手续费 
        uint256 tTransferAmount = tAmount - tFee;
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;                                                            # 这个函数是按实际币的总量与发行量的总量，重新计算
        uint256 rFee = tFee * currentRate;                                                                  # rAmount, rTransferAmount, rFee
        uint256 rTransferAmount = rAmount - rFee;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return (rSupply / tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < (_rTotal / _tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
}
