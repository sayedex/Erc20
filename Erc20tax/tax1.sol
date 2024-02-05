// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract WONDER_ENERGY_TECHNOLOGY is ERC20, ERC20Permit, Ownable {
    mapping(address => bool) public isFeeExempt;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _pairs;
    bool private feesEnabled = true;

    uint256 private holderFee;
    uint256 private marketingFee;
    uint256 private liquidityFee;
    uint256 private totalFee;
    uint256 public feeDenominator = 10000;

    // Buy Fee
    uint256 public marketingFeeBuy = 200;
    uint256 public totalFeeBuy = 200;
    // Sell Fees
    uint256 public holderFeeSell = 200;
    uint256 public liquidityFeeSell = 400;
    uint256 public totalFeeSell = 600;

    // Fees receivers
    address private devWallet;
    address private holderWallet;
    address private marketingWallet;

    constructor(
        address _devWallet,
        address _holderWallet,
        address _marketingWallet
    )
        Ownable(_devWallet)
        ERC20("WONDER ENERGY TECHNOLOGY", "WTE")
        ERC20Permit("WONDER ENERGY TECHNOLOGY")
    {
        _mint(_devWallet, 300000000 * 10**decimals());
        devWallet = _devWallet;
        holderWallet = _holderWallet;
        marketingWallet = _marketingWallet;
        transferOwnership(_devWallet);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        return _WTETransfer(_msgSender(), to, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _WTETransfer(sender, recipient, amount);
    }

    function _WTETransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        bool shouldTakeFee = feesEnabled &&
            !isFeeExempt[sender] &&
            !isFeeExempt[recipient];
        address user_ = sender;
        address pair_ = recipient;
        // Set Fees
        if (isPair(sender)) {
            buyFees();
            user_ = recipient;
            pair_ = sender;
        } else if (isPair(recipient)) {
            sellFees();
        } else {
            shouldTakeFee = false;
        }

        uint256 amountReceived = shouldTakeFee
            ? takeFee(sender, amount)
            : amount;
        _transfer(sender, recipient, amountReceived);

        return true;
    }

    function buyFees() internal {
        marketingFee = marketingFeeBuy;
        totalFee = totalFeeBuy;
    }

    function sellFees() internal {
        liquidityFee = liquidityFeeSell;
        holderFee = holderFeeSell;
        totalFee = totalFeeSell;
    }

    function takeFee(address sender, uint256 amount)
        internal
        returns (uint256)
    {
        uint256 feeAmount = (amount * totalFee) / feeDenominator;
        if (isPair(sender)) {
            _transfer(sender, devWallet, feeAmount);
        } else {
            uint256 amountWTELp = (feeAmount * liquidityFee) / (totalFee);
            uint256 amountWTEholder = (feeAmount * holderFee) / (totalFee);
            _transfer(sender, devWallet, amountWTELp);
            _transfer(sender, holderWallet, amountWTEholder);
        }
        return amount - feeAmount;
    }

    function isPair(address account) public view returns (bool) {
        return _pairs.contains(account);
    }

    function addPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "WTE: pair is the zero address");
        return _pairs.add(pair);
    }

    function delPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "WTE: pair is the zero address");
        return _pairs.remove(pair);
    }

    function getMinterLength() public view returns (uint256) {
        return _pairs.length();
    }

    function setSellFees(uint256 _holderFee, uint256 _liquidityFee)
        external
        onlyOwner
    {
        require(
            _holderFee + _liquidityFee <= 2500,
            "Total fees must be less than or equal to 25"
        );

        holderFeeSell = _holderFee;
        liquidityFeeSell = _liquidityFee;
        totalFeeSell = _holderFee + _liquidityFee;
    }

    function setBuyFees(uint256 _marketingFee) external onlyOwner {
        require(
            _marketingFee <= 2500,
            "Total fees must be less than or equal to 25"
        );
        marketingFeeBuy = _marketingFee;
        totalFeeBuy = _marketingFee;
    }

    function setFeeReceivers(
        address _devWallet,
        address _holderWallet,
        address _marketingWallet
    ) external onlyOwner {
        devWallet = _devWallet;
        holderWallet = _holderWallet;
        marketingWallet = _marketingWallet;
    }

    function setFeesEnabled(bool _feesEnabled) external onlyOwner {
        feesEnabled = _feesEnabled;
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }
}
