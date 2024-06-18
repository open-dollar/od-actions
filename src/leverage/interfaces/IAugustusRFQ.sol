// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IAugustusRFQ {
  // constants
  function FILLED_ORDER() external returns (uint256);
  function UNFILLED_ORDER() external returns (uint256);
  function RFQ_LIMIT_NFT_ORDER_TYPEHASH() external returns (bytes32);
  function RFQ_LIMIT_ORDER_TYPEHASH() external returns (bytes32);

  struct Order {
    uint256 nonceAndMeta; // Nonce and taker specific metadata
    uint128 expiry;
    address makerAsset;
    address takerAsset;
    address maker;
    address taker; // zero address on orders executable by anyone
    uint256 makerAmount;
    uint256 takerAmount;
  }

  // makerAsset and takerAsset are Packed structures
  // 0 - 159 bits are address
  // 160 - 161 bits are tokenType (0 ERC20, 1 ERC1155, 2 ERC721)
  struct OrderNFT {
    uint256 nonceAndMeta; // Nonce and taker specific metadata
    uint128 expiry;
    uint256 makerAsset;
    uint256 makerAssetId; // simply ignored in case of ERC20s
    uint256 takerAsset;
    uint256 takerAssetId; // simply ignored in case of ERC20s
    address maker;
    address taker; // zero address on orders executable by anyone
    uint256 makerAmount;
    uint256 takerAmount;
  }

  struct OrderInfo {
    Order order;
    bytes signature;
    uint256 takerTokenFillAmount;
    bytes permitTakerAsset;
    bytes permitMakerAsset;
  }

  struct OrderNFTInfo {
    OrderNFT order;
    bytes signature;
    uint256 takerTokenFillAmount;
    bytes permitTakerAsset;
    bytes permitMakerAsset;
  }

  function getRemainingOrderBalance(
    address maker,
    bytes32[] calldata orderHashes
  ) external view returns (uint256[] memory remainingBalances);

  /**
   * @notice Cancel one or more orders using orderHashes
   * @dev Cancelled orderHashes are marked as used
   * @dev Emits a Cancel event
   * @dev Out of gas may occur in arrays of length > 400
   * @param orderHashes bytes32[] List of order hashes to cancel
   */
  function cancelOrders(bytes32[] calldata orderHashes) external;

  function cancelOrder(bytes32 orderHash) external;

  /**
   * @dev Allows taker to partially fill an order
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   */
  function partialFillOrder(
    Order calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Allows taker to partially fill an NFT order
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   */
  function partialFillOrderNFT(
    OrderNFT calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Same as `partialFillOrder` but it allows to specify the destination address
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   *    @param target Address that will receive swap funds
   */
  function partialFillOrderWithTarget(
    Order calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount,
    address target
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Same as `partialFillOrderWithTarget` but it allows to pass permit
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   *    @param target Address that will receive swap funds
   *    @param permitTakerAsset Permit calldata for taker
   *    @param permitMakerAsset Permit calldata for maker
   */
  function partialFillOrderWithTargetPermit(
    Order calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount,
    address target,
    bytes calldata permitTakerAsset,
    bytes calldata permitMakerAsset
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Same as `partialFillOrderNFT` but it allows to specify the destination address
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   *    @param target Address that will receive swap funds
   */
  function partialFillOrderWithTargetNFT(
    OrderNFT calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount,
    address target
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Same as `partialFillOrderWithTargetNFT` but it allows to pass token permits
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param takerTokenFillAmount Maximum taker token to fill this order with.
   *    @param target Address that will receive swap funds
   *    @param permitTakerAsset Permit calldata for taker
   *    @param permitMakerAsset Permit calldata for maker
   */
  function partialFillOrderWithTargetPermitNFT(
    OrderNFT calldata order,
    bytes calldata signature,
    uint256 takerTokenFillAmount,
    address target,
    bytes calldata permitTakerAsset,
    bytes calldata permitMakerAsset
  ) external returns (uint256 makerTokenFilledAmount);

  /**
   * @dev Allows taker to fill complete RFQ order
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   */
  function fillOrder(Order calldata order, bytes calldata signature) external;

  /**
   * @dev Allows taker to fill Limit order
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   */
  function fillOrderNFT(OrderNFT calldata order, bytes calldata signature) external;

  /**
   * @dev Same as fillOrder but allows sender to specify the target
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param target Address of the receiver
   */
  function fillOrderWithTarget(Order calldata order, bytes calldata signature, address target) external;

  /**
   * @dev Same as fillOrderNFT but allows sender to specify the target
   *    @param order Order quote to fill
   *    @param signature Signature of the maker corresponding to the order
   *    @param target Address of the receiver
   */
  function fillOrderWithTargetNFT(OrderNFT calldata order, bytes calldata signature, address target) external;

  /**
   * @dev Partial fill multiple orders
   *    @param orderInfos OrderInfo to fill
   *    @param target Address of receiver
   */
  function batchFillOrderWithTarget(OrderInfo[] calldata orderInfos, address target) external;

  /**
   * @dev batch fills orders until the takerFillAmount is swapped
   *    @dev skip the order if it fails
   *    @param orderInfos OrderInfo to fill
   *    @param takerFillAmount total taker amount to fill
   *    @param target Address of receiver
   */
  function tryBatchFillOrderTakerAmount(
    OrderInfo[] calldata orderInfos,
    uint256 takerFillAmount,
    address target
  ) external;

  /**
   * @dev batch fills orders until the makerFillAmount is swapped
   *    @dev skip the order if it fails
   *    @param orderInfos OrderInfo to fill
   *    @param makerFillAmount total maker amount to fill
   *    @param target Address of receiver
   */
  function tryBatchFillOrderMakerAmount(
    OrderInfo[] calldata orderInfos,
    uint256 makerFillAmount,
    address target
  ) external;

  /**
   * @dev Partial fill multiple NFT orders
   *    @param orderInfos Info about each order to fill
   *    @param target Address of receiver
   */
  function batchFillOrderWithTargetNFT(OrderNFTInfo[] calldata orderInfos, address target) external;
}
