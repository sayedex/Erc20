// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "hardhat/console.sol";

contract WTE_Public_Sale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    AggregatorV3Interface internal dataFeed;
    uint256 public nextTokenId;
    uint256 public totalSold;

    // treasury wallet
    address public treasuryWallet;
    bool public _saleEnd = false;
    uint256 public endTimestamp;
    address public presaleToken;
    uint256 public priceInBNB;
    uint256 multiplier = 10**18; // 18 decimal places

    // payment token stuck
    struct PaymentToken {
        address _tokenaddress;
        uint8 _decimals;
    }

    // only stabe token suppoted
    mapping(uint256 => PaymentToken) public tokenInfo;

    constructor(
        address _treasuryWallet,
        uint256 _endTimestamp,
        uint256 _price,
        address _presaleToken
    ) Ownable(_treasuryWallet) {
        dataFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );

        treasuryWallet = _treasuryWallet;
        endTimestamp = _endTimestamp;
        priceInBNB = _price;
        presaleToken = _presaleToken;
    }

    modifier FullfillRequirement() {
        require(
            !_saleEnd || block.timestamp >= endTimestamp,
            "sale not active!"
        );
        _;
    }

    // Function to update the treasuryWallet address
    function setTreasuryWallet(address _newTreasuryWallet) external onlyOwner {
        require(
            _newTreasuryWallet != address(0),
            "Invalid treasury wallet address"
        );
        treasuryWallet = _newTreasuryWallet;
    }

    function setPrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid token price");
        priceInBNB = _price;
    }

    function toggleSaleEnd() external onlyOwner {
        _saleEnd = !_saleEnd;
    }

    function buyWithBNB() external payable nonReentrant FullfillRequirement {
        require(msg.value > 0, "Incorrect BNB amount sent");
        uint256 tokensToBuy = msg.value.mul(multiplier).div(priceInBNB);
        require(tokensToBuy > 0, "Invalid token amount");
        // Transfer BNB to the treasury wallet
        payable(treasuryWallet).transfer(msg.value);
        // Perform the token transfer
        transferCurrency(presaleToken, treasuryWallet, msg.sender, tokensToBuy);
        totalSold += tokensToBuy;
    }

    function buyWithToken(uint256 tokenId, uint256 _tokenAmount)
        external
        nonReentrant
        FullfillRequirement
    {
        require(
            tokenInfo[tokenId]._tokenaddress != address(0),
            "Payment token not set"
        );
        uint256 tokenAmountInWei = _tokenAmount *
            10**(18 -tokenInfo[tokenId]._decimals);
        // console.log("tokenAmountInWei",tokenAmountInWei);
        uint256 bnbAmount = tokenAmountInWei.mul(multiplier).div(
            getLatestBNBPrice()
        );
        // console.log("bnbAmount",bnbAmount);
        require(bnbAmount > 0, "Invalid BNB amount");
        uint256 tokensToBuy= bnbAmount.mul(multiplier).div(priceInBNB);
        // console.log("tokensToBuy",tokensToBuy);
        transferCurrency(
            tokenInfo[tokenId]._tokenaddress,
            msg.sender,
            treasuryWallet,
            _tokenAmount
        );
        transferCurrency(presaleToken, treasuryWallet, msg.sender, tokensToBuy);
        totalSold += tokensToBuy;
    }

    // Function to set payment token information
    function setPaymentToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        tokenInfo[nextTokenId] = PaymentToken({
            _tokenaddress: _tokenAddress,
            _decimals: IERC20Metadata(_tokenAddress).decimals()
        });
        nextTokenId++;
    }

    function getLatestBNBPrice() internal view returns (uint256) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
     uint256 bnbPriceUint = uint256(price);
     return (bnbPriceUint * 10**(10));
       //return uint256(320000000000000000000);
    }

    function getLatestBNBPricePublic() public view returns (uint256) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 bnbPriceUint = uint256(price);
        return (bnbPriceUint / 10**8);
    }

    /// @dev Transfers a given amount of currency.
    function transferCurrency(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }
        safeTransferERC20(_currency, _from, _to, _amount);
    }

    // @dev Transfer `amount` of ERC20 token from `from` to `to`.
    function safeTransferERC20(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_from == _to) {
            return;
        }

        if (_from == address(this)) {
            IERC20(_currency).safeTransfer(_to, _amount);
        } else {
            IERC20(_currency).safeTransferFrom(_from, _to, _amount);
        }
    }
}
