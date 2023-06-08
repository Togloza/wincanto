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


    function Approve(address operator, uint tokenID) external {
        winTokenAddress._Approve(operator, tokenID);
    }

    function burn(uint256 _tokenID) external {
        winTokenAddress.burn(tokenID);
    }

     function OwnerOf(uint256 tokenID) external view returns (address) {
        winTokenAddress._OwnerOf(tokenID);
     }



     function findWinningNFTAddress() external view returns (address, uint) {
        return winnerCalculatorAddress.findWinningNFTAddress();
     }

     function publishWinningAddress(address winnerAddress) external {
        winnerCalculatorAddress.publishDayWinningAddress(winnerAddress);
     }

     function getTotalStakedAmounts() public view returns (uint, uint) {
        return winnerCalculatorAddress.getTotalStakedAmounts;
     }

     function getDailyWinningAmount() public view returns (uint){
        return winnerCalculatorAddress.getDailyWinningAmount();
     }
    function getWeeklyWinningAmount() public view returns (uint){
        return winnerCalculatorAddress.getWeeklyWinningAmount();
     }

    function isReadyToDraw() public view returns (bool) {
        return winnerCalculatorAddress.isReadyToDraw();
    }

    function isWeekReward() public view returns (bool) {
        return winnerCalculatorAddress.isWeekReward();
    }




    function getStakingContractBalance() external view returns (uint){
        return stakingAddress.getContractBalance();
    }




}