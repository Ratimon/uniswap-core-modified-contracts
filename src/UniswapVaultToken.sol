// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IUniswapVaultToken} from './interfaces/IUniswapVaultToken.sol';


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";


abstract contract UniswapVaultToken is IUniswapVaultToken, ERC20  {
    using Math for uint256;

    IERC20 private immutable _asset0;
    IERC20 private immutable _asset1;

    // uint8 private immutable _underlyingDecimals0;
    // uint8 private immutable _underlyingDecimals1;
    uint8 private immutable _underlyingDecimals;


    constructor(IERC20 asset0_, IERC20 asset1_) ERC20('Uniswap V2', 'UNI-V2') {

        (bool success0, uint8 asset0Decimals) = _tryGetAssetDecimals(asset0_);
        uint8 underlyingDecimals0 = success0 ? asset0Decimals : 18;
        _asset0 = asset0_;

        (bool success1, uint8 asset1Decimals) = _tryGetAssetDecimals(asset0_);
        // _underlyingDecimals1 = success1 ? asset1Decimals : 18;
        uint8 underlyingDecimals1 = success1 ? asset1Decimals : 18;
        _asset1 = asset1_;

        require(underlyingDecimals0 == underlyingDecimals1, "decimals must equal");
        _underlyingDecimals = underlyingDecimals0;

    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
     function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset_).staticcall(
            abi.encodeWithSelector(IERC20Metadata.decimals.selector)
        );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }


    //  function decimals0() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
    //     return _underlyingDecimals0 + _decimalsOffset();
    // }

    // function decimals1() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
    //     return _underlyingDecimals0 + _decimalsOffset();
    // }

     function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    function asset0() public view virtual override returns (address) {
        return address(_asset0);
    }

    function asset1() public view virtual override returns (address) {
        return address(_asset1);
    }

    function totalAssets() public view virtual returns (uint256);
    

    // function totalAssets() public view virtual override returns (uint256) {
    //     (uint112 _reserve0, uint112 _reserve1,) = getReserves();
    //     // return _asset.balanceOf(address(this));
    //     return Math.min(a, b);
    // }
    

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxMint}. */
    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }

    /** @dev See {IERC4626-previewDeposit}. */
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    /** @dev See {IERC4626-previewMint}. */
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Up);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-mint}.
        *
        * As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
        * In this case, the shares will be minted without requiring any assets to be deposited.
        */
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
        * @dev Internal conversion function (from assets to shares) with support for rounding direction.
        */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
        * @dev Internal conversion function (from shares to assets) with support for rounding direction.
        */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    // function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
    //     SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
    //     _mint(receiver, shares);

    //     emit Deposit(caller, receiver, assets, shares);
    // }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual;
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual;
    


}

