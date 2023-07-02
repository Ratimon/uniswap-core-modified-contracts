// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IUniswapVaultToken} from "./interfaces/IUniswapVaultToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {UD60x18, intoUint128, intoUint256, ud, unwrap} from "@prb-math/UD60x18.sol";

contract UniswapV2PairVault is IUniswapVaultToken, IERC3156FlashLender, ERC20, Initializable {
    using Math for uint256;
    using SafeMath for uint256;

    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error RepayFailed();
    error UnsupportedCurrency();
    error CallbackFailed();

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint128 reserve0, uint128 reserve1);

    IERC20 private _token0;
    IERC20 private _token1;

    uint8 private _underlyingDecimals;

    address public factory;

    uint128 private reserve0; // uses single storage slot, accessible via getReserves
    uint128 private reserve1; // uses single storage slot, accessible via getReserves

    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint8 private flashLoanFee;

    constructor() ERC20("Uniswap V2", "UNI-V2") {
        factory = msg.sender;
    }

    function initialize(IERC20 token0_, IERC20 token1_, uint8 flashLoanFee_) external initializer {
        (bool success0, uint8 asset0Decimals) = _tryGetAssetDecimals(token0_);
        uint8 underlyingDecimals0 = success0 ? asset0Decimals : 18;
        _token0 = token0_;

        (bool success1, uint8 asset1Decimals) = _tryGetAssetDecimals(token1_);
        uint8 underlyingDecimals1 = success1 ? asset1Decimals : 18;
        _token1 = token1_;

        require(underlyingDecimals0 == underlyingDecimals1, "decimals must equal");
        _underlyingDecimals = underlyingDecimals0;

        flashLoanFee = flashLoanFee_;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint128 _reserve0, uint128 _reserve1) private {
        // require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += intoUint256(UD60x18.wrap(_reserve1).div(ud(_reserve0)).mul(ud(timeElapsed)));
            price1CumulativeLast += intoUint256(UD60x18.wrap(_reserve0).div(ud(_reserve1)).mul(ud(timeElapsed)));
        }
        reserve0 = uint128(balance0);
        reserve1 = uint128(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
    function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) =
            address(asset_).staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    function asset0() public view virtual override returns (address) {
        return address(_token0);
    }

    function asset1() public view virtual override returns (address) {
        return address(_token1);
    }

    function totalAssets() public view virtual returns (uint128 totalManagedAssets0, uint128 totalManagedAssets1) {
        return (reserve0, reserve1);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 4;
    }

    function convertToShares(uint256 assets0, uint256 assets1) public view virtual override returns (uint256) {
        return _convertToShares(assets0, assets1, Math.Rounding.Down);
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets0, uint256 assets1) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    function maxDeposit(address) public view virtual override returns (uint256, uint256) {
        return (type(uint256).max, type(uint256).max);
    }

    // function maxMint(address) public view virtual override returns (uint256) {
    //     return type(uint256).max;
    // }

    // function maxWithdraw(address owner) public view virtual override returns (uint256, uint256) {
    //     return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    // }

    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets0, uint256 assets1) public view virtual override returns (uint256) {
        return _convertToShares(assets0, assets1, Math.Rounding.Down);
    }

    // function previewMint(uint256 shares) public view virtual override returns (uint256, uint256) {
    //     return _convertToAssets(shares, Math.Rounding.Up);
    // }

    // function previewWithdraw(uint256 assets0, uint256 assets1) public view virtual override returns (uint256) {
    //     return _convertToShares(assets0, assets1, Math.Rounding.Up);
    // }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256, uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    // function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
    //     require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

    //     uint256 shares = previewDeposit(assets);
    //     _deposit(_msgSender(), receiver, assets, shares);

    //     return shares;
    // }

    function deposit(uint256 assets0, uint256 assets1, address receiver)
        public
        virtual
        override
        returns (uint256 shares)
    {
        (uint256 maxAssets0, uint256 maxAssets1) = maxDeposit(receiver);
        require((assets0 <= maxAssets0) && (assets1 <= maxAssets1), "ERC4626: deposit more than max");

        // Need to transfer before minting to avoid reenter.
        SafeERC20.safeTransferFrom(_token0, msg.sender, address(this), assets0);
        SafeERC20.safeTransferFrom(_token1, msg.sender, address(this), assets1);

        (uint128 _reserve0, uint128 _reserve1) = totalAssets();

        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));

        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        shares = previewDeposit(amount0, amount1);

        _mint(receiver, shares);
        _update(balance0, balance1, _reserve0, _reserve1);

        emit Deposit(msg.sender, receiver, assets0, assets1, shares);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (token == address(_token0)) {
            return _token0.balanceOf(address(this));
        }
        if (token == address(_token1)) {
            return _token1.balanceOf(address(this));
        }
        return 0;
    }

    function flashFee(address token, uint256 amount) public view returns (uint256) {

        // if ( token == address(_token0)) {
        //     return _token0.balanceOf(address(this)).mul( uint256(flashLoanFee)).div(100);
        // } else if  (token == address(_token1)) {
        //     return _token1.balanceOf(address(this)).mul( uint256(flashLoanFee)).div(100);
        // } else {
        //     revert UnsupportedCurrency();
        // }

        if ( token != address(_token0) &&  token != address(_token1) ) {
            revert UnsupportedCurrency();
        }

        return amount.mul( uint256(flashLoanFee)).div(100);
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        if ( token != address(_token0) &&  token != address(_token1) ) {
            revert UnsupportedCurrency();
        }

        IERC20 _token = IERC20(token);
        uint256 balanceBefore = _token.balanceOf(address(this));

        SafeERC20.safeTransfer(_token, address(receiver), amount);

        uint256 fee = flashFee(token, amount);

        if (receiver.onFlashLoan(msg.sender, address(_token), amount, fee, data) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }

        if (_token.balanceOf(address(this)) < balanceBefore + fee) {
            revert RepayFailed();
        }

        return true;
    }

    // function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
    //     require(shares <= maxMint(receiver), "ERC4626: mint more than max");

    //     uint256 assets = previewMint(shares);
    //     _deposit(_msgSender(), receiver, assets, shares);

    //     return assets;
    // }

    // function mint(uint256 shares, address receiver) public virtual override returns (uint256, uint256);

    // function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
    //     require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

    //     uint256 shares = previewWithdraw(assets);
    //     _withdraw(_msgSender(), receiver, owner, assets, shares);

    //     return shares;
    // }

    // function withdraw(uint256 assets0, uint256 assets1, address receiver, address owner) public virtual override returns (uint256);

    // function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
    //     require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

    //     uint256 assets = previewRedeem(shares);
    //     _withdraw(_msgSender(), receiver, owner, assets, shares);

    //     return assets;
    // }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 assets0, uint256 assets1)
    {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        (assets0, assets1) = previewRedeem(shares);
        require(assets0 > 0 && assets1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(owner, shares);

        (uint128 _reserve0, uint128 _reserve1) = totalAssets();

        // Need to transfer before returning asser to avoid reenter.
        SafeERC20.safeTransfer(_token0, receiver, assets0);
        SafeERC20.safeTransfer(_token1, receiver, assets1);

        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);

        emit Withdraw(msg.sender, receiver, owner, assets0, assets1, shares);
    }

    function swap(uint amount0Out, uint amount1Out, address receiver) external {

        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint128 _reserve0, uint128 _reserve1) = totalAssets();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        if (amount0Out > 0)  SafeERC20.safeTransfer(_token0, receiver, amount0Out);
        if (amount1Out > 0)  SafeERC20.safeTransfer(_token1, receiver, amount1Out);
        
        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));

        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');

        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));

        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');

        _update(balance0, balance1, _reserve0, _reserve1);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, receiver);
    }



    function _convertToShares(uint256 assets0, uint256 assets1, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return Math.sqrt(assets0 * assets1);
        } else {
            (uint128 _reserve0, uint128 _reserve1) = totalAssets();

            uint256 liquidity0 = assets0.mulDiv(totalSupply() + 10 ** _decimalsOffset(), _reserve0 + 1, rounding);
            uint256 liquidity1 = assets1.mulDiv(totalSupply() + 10 ** _decimalsOffset(), _reserve1 + 1, rounding);
            return Math.min(liquidity0, liquidity1);
        }
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256, uint256)
    {
        // (uint256 balance0, uint256 balance1 )= totalAssets();
        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));

        return (
            shares.mulDiv(balance0 + 1, totalSupply() + 10 ** _decimalsOffset(), rounding),
            shares.mulDiv(balance1 + 1, totalSupply() + 10 ** _decimalsOffset(), rounding)
        );
    }

    // function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
    //     SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
    //     _mint(receiver, shares);

    //     emit Deposit(caller, receiver, assets, shares);
    // }

    // function _deposist(address caller, address receiver, uint256 assets, uint256 shares) internal virtual;

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

    // function _withdraw(
    //     address caller,
    //     address receiver,
    //     address owner,
    //     uint256 assets,
    //     uint256 shares
    // ) internal virtual;
}
