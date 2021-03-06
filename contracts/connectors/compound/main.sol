pragma solidity ^0.7.0;

import { TokenInterface } from "../../common/interfaces.sol";
import { Stores } from "../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { CETHInterface, CTokenInterface } from "./interface.sol";

abstract contract CompoundResolver is Events, Helpers {
    /**
     * @dev Deposit ETH/ERC20_Token.
     * @param token token address to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to deposit.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function deposit(
        address token,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cToken = instaMapping.cTokenMapping(token);
        enterMarket(cToken);
        if (token == ethAddr) {
            _amt = _amt == uint(-1) ? address(this).balance : _amt;
            CETHInterface(cToken).mint{value: _amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            _amt = _amt == uint(-1) ? tokenContract.balanceOf(address(this)) : _amt;
            tokenContract.approve(cToken, _amt);
            require(CTokenInterface(cToken).mint(_amt) == 0, "deposit-failed");
        }
        setUint(setId, _amt);

        _eventName = "LogDeposit(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, _amt, getId, setId);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @param token token address to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to withdraw.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function withdraw(
        address token,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cToken = instaMapping.cTokenMapping(token);
        CTokenInterface cTokenContract = CTokenInterface(cToken);
        if (_amt == uint(-1)) {
            TokenInterface tokenContract = TokenInterface(token);
            uint initialBal = token == ethAddr ? address(this).balance : tokenContract.balanceOf(address(this));
            require(cTokenContract.redeem(cTokenContract.balanceOf(address(this))) == 0, "full-withdraw-failed");
            uint finalBal = token == ethAddr ? address(this).balance : tokenContract.balanceOf(address(this));
            _amt = finalBal - initialBal;
        } else {
            require(cTokenContract.redeemUnderlying(_amt) == 0, "withdraw-failed");
        }
        setUint(setId, _amt);

        _eventName = "LogWithdraw(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, _amt, getId, setId);
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @param token token address to borrow.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to borrow.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function borrow(
        address token,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cToken = instaMapping.cTokenMapping(token);
        enterMarket(cToken);
        require(CTokenInterface(cToken).borrow(_amt) == 0, "borrow-failed");
        setUint(setId, _amt);

        _eventName = "LogBorrow(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, _amt, getId, setId);
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @param token token address to payback.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to payback.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function payback(
        address token,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cToken = instaMapping.cTokenMapping(token);
        CTokenInterface cTokenContract = CTokenInterface(cToken);
        _amt = _amt == uint(-1) ? cTokenContract.borrowBalanceCurrent(address(this)) : _amt;

        if (token == ethAddr) {
            require(address(this).balance >= _amt, "not-enough-eth");
            CETHInterface(cToken).repayBorrow{value: _amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            require(tokenContract.balanceOf(address(this)) >= _amt, "not-enough-token");
            tokenContract.approve(cToken, _amt);
            require(cTokenContract.repayBorrow(_amt) == 0, "repay-failed.");
        }
        setUint(setId, _amt);

        _eventName = "LogPayback(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, _amt, getId, setId);
    }

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @param token token address to depositCToken.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to depositCToken.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set ctoken amount at this ID in `InstaMemory` Contract.
    */
    function depositCToken(
        address token,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cToken = instaMapping.cTokenMapping(token);
        enterMarket(cToken);

        CTokenInterface ctokenContract = CTokenInterface(cToken);
        uint initialBal = ctokenContract.balanceOf(address(this));

        if (token == ethAddr) {
            _amt = _amt == uint(-1) ? address(this).balance : _amt;
            CETHInterface(cToken).mint{value: _amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            _amt = _amt == uint(-1) ? tokenContract.balanceOf(address(this)) : _amt;
            tokenContract.approve(cToken, _amt);
            require(ctokenContract.mint(_amt) == 0, "deposit-ctoken-failed.");
        }

        uint finalBal = ctokenContract.balanceOf(address(this));
        uint _cAmt = finalBal - initialBal;
        setUint(setId, _cAmt);

        _eventName = "LogDepositCToken(address,address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, _amt, _cAmt, getId, setId);
    }

    /**
     * @dev Withdraw CETH/CERC20_Token using cToken Amt.
     * @param token token address to withdraw CToken.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param cTokenAmt ctoken amount to withdrawCToken.
     * @param getId Get ctoken amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function withdrawCToken(
        address token,
        uint cTokenAmt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _cAmt = getUint(getId, cTokenAmt);
        address cToken = instaMapping.cTokenMapping(token);
        CTokenInterface cTokenContract = CTokenInterface(cToken);
        TokenInterface tokenContract = TokenInterface(token);
        _cAmt = _cAmt == uint(-1) ? cTokenContract.balanceOf(address(this)) : _cAmt;

        uint initialBal = token != ethAddr ? tokenContract.balanceOf(address(this)) : address(this).balance;
        require(cTokenContract.redeem(_cAmt) == 0, "redeem-failed");
        uint finalBal = token != ethAddr ? tokenContract.balanceOf(address(this)) : address(this).balance;

        uint withdrawAmt = sub(finalBal, initialBal);
        setUint(setId, withdrawAmt);

        _eventName = "LogWithdrawCToken(address,address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, withdrawAmt, _cAmt, getId, setId);
    }

    /**
     * @dev Liquidate a position.
     * @param borrower Borrower's Address.
     * @param tokenToPay token address to pay for liquidation.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param tokenInReturn token address to return for liquidation.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to pay for liquidation.
     * @param getId Get token amount at this ID from `InstaMemory` Contract.
     * @param setId Set token amount at this ID in `InstaMemory` Contract.
    */
    function liquidate(
        address borrower,
        address tokenToPay,
        address tokenInReturn,
        uint amt,
        uint getId,
        uint setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        address cTokenPay = instaMapping.cTokenMapping(tokenToPay);
        address cTokenColl = instaMapping.cTokenMapping(tokenInReturn);
        CTokenInterface cTokenContract = CTokenInterface(cTokenPay);

        {
            (,, uint shortfal) = troller.getAccountLiquidity(borrower);
            require(shortfal != 0, "account-cannot-be-liquidated");
        }

        _amt = _amt == uint(-1) ? cTokenContract.borrowBalanceCurrent(borrower) : _amt;
        if (tokenToPay == ethAddr) {
            require(address(this).balance >= _amt, "not-enought-eth");
            CETHInterface(cTokenPay).liquidateBorrow{value: _amt}(borrower, cTokenColl);
        } else {
            TokenInterface tokenContract = TokenInterface(tokenToPay);
            require(tokenContract.balanceOf(address(this)) >= _amt, "not-enough-token");
            tokenContract.approve(cTokenPay, _amt);
            require(cTokenContract.liquidateBorrow(borrower, _amt, cTokenColl) == 0, "liquidate-failed");
        }
        
        setUint(setId, _amt);

        _eventName = "LogLiquidate(address,address,address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(
            address(this),
            tokenToPay,
            tokenInReturn, 
            _amt,
            getId,
            setId
        );
    }
}

contract ConnectCompound is CompoundResolver {
    string public name = "Compound-v1.3";
}
