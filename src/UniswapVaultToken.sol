// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IUniswapVaultToken} from './interfaces/IUniswapVaultToken.sol';


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";


abstract contract UniswapVaultToken is IUniswapVaultToken, ERC20, Initializable  {
    using Math for uint256;

    IERC20 private _asset0;
    IERC20 private _asset1;

    // uint8 private immutable _underlyingDecimals0;
    // uint8 private immutable _underlyingDecimals1;
    uint8 private _underlyingDecimals;


    constructor() ERC20('Uniswap V2', 'UNI-V2') {

    }

    function __UniswapVaultToken_init(IERC20 asset0_, IERC20 asset1_) internal onlyInitializing {
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

    function maxDeposit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    }

    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Up);
    }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    // function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
    //     require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

    //     uint256 shares = previewDeposit(assets);
    //     _deposit(_msgSender(), receiver, assets, shares);

    //     return shares;
    // }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256);


    // function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
    //     require(shares <= maxMint(receiver), "ERC4626: mint more than max");

    //     uint256 assets = previewMint(shares);
    //     _deposit(_msgSender(), receiver, assets, shares);

    //     return assets;
    // }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256);

    // function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
    //     require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

    //     uint256 shares = previewWithdraw(assets);
    //     _withdraw(_msgSender(), receiver, owner, assets, shares);

    //     return shares;
    // }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256);

    // function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
    //     require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

    //     uint256 assets = previewRedeem(shares);
    //     _withdraw(_msgSender(), receiver, owner, assets, shares);

    //     return assets;
    // }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256);

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    // function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
    //     SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
    //     _mint(receiver, shares);

    //     emit Deposit(caller, receiver, assets, shares);
    // }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual;

    // function _withdraw(
    //     address caller,
    //     address receiver,
    //     address owner,
    //     uint256 assets,
    //     uint256 shares
    // ) internal virtual {
    //     if (caller != owner) {
    //         _spendAllowance(owner, caller, shares);
    //     }

    //     // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
    //     // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
    //     // calls the vault, which is assumed not malicious.
    //     //
    //     // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
    //     // shares are burned and after the assets are transferred, which is a valid state.
    //     _burn(owner, shares);
    //     SafeERC20.safeTransfer(_asset, receiver, assets);

    //     emit Withdraw(caller, receiver, owner, assets, shares);
    // }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual;
    


}

