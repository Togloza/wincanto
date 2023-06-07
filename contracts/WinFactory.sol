// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./WinToken.sol";
import "./IWinToken.sol";
import "./ConversionHelper.sol";
import "./WinnerCalculator.sol";
import "./Metadata.sol";
import "./WinStaking.sol";

contract FactoryContract {
    address public winTokenAddress;
    address public iwinTokenAddress;
    address public conversionHelperAddress;
    address public winnerCalculatorAddress;
    address public metadataAddress;
    address public stakingAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    ) {
        // Deploy winToken contract
        winTokenAddress = address(new WinToken(_name, _symbol, _royaltyRecipient, _royaltyBps));
        // Retrieve the turnstileTokenId from the deployed winToken contract
        // uint256 turnstileTokenId = winTokenAddress.turnstileTokenId();
        // Deploy IwinToken contract
        iwinTokenAddress = address(new IWinToken());

        // Deploy ConversionHelper contract
        conversionHelperAddress = address(new ConversionHelper());

        // Deploy WinnerCalculator contract
        winnerCalculatorAddress = address(new WinnerCalculator(winTokenAddress));

        // Deploy Metadata contract
        metadataAddress = address(new Metadata());

        // Deploy Staking contract
        stakingAddress = address(new WinStaking(winTokenAddress));
    }

}