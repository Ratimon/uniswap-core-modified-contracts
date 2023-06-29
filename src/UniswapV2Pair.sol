// // SPDX-License-Identifier: MIT
// pragma solidity =0.8.19;

// import {UniswapVaultToken} from './UniswapVaultToken.sol';


// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// // import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// // import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";



// contract UniswapV2Pair is UniswapVaultToken {

//     address public factory;

//     uint112 private reserve0;           // uses single storage slot, accessible via getReserves
//     uint112 private reserve1;           // uses single storage slot, accessible via getReserves

//     constructor() {
//         factory = msg.sender;
//     }

//     // called once by the factory at time of deployment
//     function initialize(address _token0, address _token1) external {
//         require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
//         __UniswapVaultToken_init(IERC20(_token0), IERC20(_token1));
//     }

//     function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
//         _reserve0 = reserve0;
//         _reserve1 = reserve1;
//     }

//     function totalAssets() public view virtual override returns (uint256 totalManagedAssets_) {

//         if (totalSupply() == 0) return 0;

//         (uint112 _reserve0, uint112 _reserve1) = getReserves();

//         return Math.max(_reserve0, _reserve1);


//     }

//     function deposit(uint256 assets0, uint256 assets1, address receiver) public virtual override returns (uint256 shares) {

//         // Need to transfer before minting to avoild reenter.
//         SafeERC20.safeTransferFrom(asset0(), msg.sender, address(this), assets0);
//         SafeERC20.safeTransferFrom(asset1(), msg.sender, address(this), assets1);


//         if (totalSupply == 0) {

//             shares = Math.sqrt(assets0 * assets1);

//         } else {

//             // liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);

//             shares  = Math.min( convertToShares(assets0), convertToShares(assets1)) ;

//         }

//         // SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
//         // _mint(receiver, shares);

//         // emit Deposit(caller, receiver, assets, shares);


//         return 0;
//     }


//     function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
//         return 0;
//     }


//     function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
//         return 0;
//     }


//     function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256){
//         return 0;
//     }

//     function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override{

//         // SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
//         // _mint(receiver, shares);

//         // emit Deposit(caller, receiver, assets, shares);

//     }

//     function _withdraw(
//         address caller,
//         address receiver,
//         address owner,
//         uint256 assets,
//         uint256 shares
//     ) internal override{

//     }
    

// }
