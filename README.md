# fuck_AidiInu
AidiInu智能合约代码解读
分红币不可能实现没一次交易精确的1%销毁，%1奖励，因为以太链上的没一次计算都要消耗gas，如果地址成千上万，说明实时奖励要返回到每一个地址。
所以他是使用另外一个模式：
      Y=K·X   --->   K=Y/X
      Y是_rTotal，真正销毁的是_rTotal，用户拥有的也是_rTotal中的_rMount,然后按系数K折算成Aidi币
      X是_tTotal   
      用户拥有余额计算方式是：rOwned[account] / currentRate = rOwned[account] / K
当Y销毁了，回导致K减少，也就是持币会增加。
         

# 具体的关键代码
```
sender            	     --->                       recipient
        tAmount= tTransferAmount(98%) + tFee(2%)
		
		currentRate = rSupply / tSupply   就是   _rTotal / _tTotal，货币供应总量/ aidi发行总量		
		
		rAmount = tAmount * currentRate;  // currentRate 其实就是K
		
		rFee = tFee * currentRate;                    
		rTransferAmount = rAmount - rFee;             
		
		rAmount, rTransferAmount, rFee, tTransferAmount, tFee		
		
		_rOwned[sender] = _rOwned[sender] - rAmount;                                                                            
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;   

		
         _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
		
		_rOwned[account] / currentRate
```
# 举例计算
```
     供应总量     发行总量
     100000      1000
 A:  10000       100
 B:  10000       100
 C:  10000       100
 
A交易100给C 清仓,目前currentRate=100

     99800       1000
 A:  0           0
 B:  10000       100.2004008
 C:  19800       198.39
```
