// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceFeedManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Manages the retrieval of token prices in native currency (e.g., AVAX) using Chainlink oracles.
 */
contract PriceFeedManager is Ownable {
    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // Address of the Chainlink aggregator providing the native token to USD price.
    address public nativeTokenUsd_Pair =
        0x5498BB86BC934c8D34FDA08E81D444153d0D06aD;

    // =============================================================
    //                               ERRORS
    // =============================================================

    // Custom error for invalid parameters.
    error ParameterError();
    
    // Custom error for failed price requests.
    error PriceRequestError();

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @dev Constructor that sets the contract owner.
     */
    constructor() Ownable(_msgSender()) {}

    // =============================================================
    //                         PUBLIC FUNCTIONS
    // =============================================================

    /**
     * @dev Retrieves the price of the native token in terms of USD.
     * @param usdAmount The amount in USD (with 18 decimals).
     * @return coinPrice The equivalent amount of native token.
     */
    function getTokenNativePrice(int usdAmount)
        external
        view
        returns (int coinPrice)
    {
        if (usdAmount < 0) revert ParameterError();
        if (usdAmount == 0) return 0;

        // Fetches the latest price and decimals from the Chainlink aggregator.
        (int pairPrice, uint8 pairDecimals) = _getChainlinkDataFeedLatestAnswer(
            nativeTokenUsd_Pair
        );

        // Ensures a valid and positive price is received.
        if (pairPrice <= 0) revert PriceRequestError();

        // Adjusts the pair price based on the decimals and calculates the coin price.
        pairPrice = pairPrice * int(10) ** (18 - pairDecimals);
        coinPrice = (10 ** 18 * usdAmount) / pairPrice;
    }

    // =============================================================
    //                         PRIVATE FUNCTIONS
    // =============================================================

    /**
     * @dev Retrieves the latest price and decimals from the specified Chainlink aggregator.
     * @param pair The address of the Chainlink aggregator.
     * @return price The latest price of the token in USD.
     * @return decimals The decimals of the token price.
     */
    function _getChainlinkDataFeedLatestAnswer(address pair)
        private
        view
        returns (int price, uint8 decimals)
    {
        AggregatorV3Interface aggregator = AggregatorV3Interface(pair);
        decimals = aggregator.decimals();
        (
            /* uint80 roundID */,
            price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = aggregator.latestRoundData();
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @dev Updates the address of the Chainlink aggregator providing the native token to USD price.
     * @param pairAddress The new address of the Chainlink aggregator.
     */
    function updatePairAddress(address pairAddress) external onlyOwner {
        nativeTokenUsd_Pair = pairAddress;
    }
}