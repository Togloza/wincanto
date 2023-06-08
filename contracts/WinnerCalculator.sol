// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// Import relevant contracts
import "@thirdweb-dev/contracts/extension/Ownable.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";
import "./IWinToken.sol";
// Interface for ERC721 contract.
 
contract WinnerCalculator is Ownable, IWinToken, Permissions {

    struct User {
        uint stakingAmount;
        bool stakingStatus;
        uint initialTimestamp; // Currently unused, but may implement in the future.
    }

    mapping(uint => User) public users;

    bytes32 public constant BRONZE_ACCESS = keccak256("BRONZE_ACCESS_ROLE");


    // Total Rewards in contract
    uint public totalRewards;

    // What percentage staked rewards are given out. 
    uint payoutPercent = 8;

    // Initialize ERC721 token address.
    IWinToken nftTokenAddress;
 
    // Keep track if weekly reward due
    uint dayCounter = 1; 

    // Updated when winner is published
    uint public winnerTimestamp;

    mapping(address => uint) public winnerRewards;

 
    constructor(IWinToken _nftTokenAddress) {
        require(address(_nftTokenAddress) != address(0), "address 0");
        nftTokenAddress = _nftTokenAddress;
        _setupRole(BRONZE_ACCESS, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    event winnerChosen(address winner, uint winningAmount);

    // Generate a random number using current blockchain data and a random input.
    function generateRandomNumber(uint256 input) internal view returns (uint256) {
        // While miners can influece block.timestamp, block.number, the function is a read function
        // And when we run the function is up to us and fairly random. 
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.number, input))
        );
        return randomNumber;
    }
    // Read function to find the winning address and tokenID
    function findWinningNFTAddress() public view returns (address, uint) {
        uint winningID = calculateWinningNFTID();
        address winner = nftTokenAddress._OwnerOf(winningID);
        
        return (winner, winningID);
    }
    // Write function to update contract on winner and amount.
    function publishWinningAddress(address winnerAddress) external {
        uint winningAmount; 
        if (dayCounter % 7 == 0){
            winningAmount = getWeeklyWinningAmount();
        }
        else {
            winningAmount = getDailyWinningAmount(); 
        } 
        
        winnerRewards[winnerAddress] += winningAmount;
        totalRewards += winningAmount;
        winnerTimestamp = block.timestamp;
        dayCounter += 1;
        emit winnerChosen(winnerAddress, winningAmount);
    } 
 
   
    // Function to calculate the ID of the winning NFTID.
    // Chances of winning are proportional to the amount staked by the users.
    // Only NFTs with stakingStatus true are counted.
    function calculateWinningNFTID() internal view returns (uint) {
        uint totalStakingAmount = 0;

        // Calculate the cumulative staking amounts of users with stakingStatus set to true
        for (uint i = 0; i < nftTokenAddress.getNextTokenID(); i++) {
            if (users[i].stakingStatus) {
                totalStakingAmount += users[i].stakingAmount;
            }
        }

        // Generate a random number within the range of the cumulative staking amounts
        uint randomNum = generateRandomNumber(totalStakingAmount) % totalStakingAmount;

        // Find the winner by iterating over the users and checking the cumulative staking amounts
        uint cumulativeAmount = 0;
        for (uint i = 0; i < nftTokenAddress.getNextTokenID(); i++) {
            if (users[i].stakingStatus) {
                cumulativeAmount += users[i].stakingAmount;
                if (randomNum <= cumulativeAmount) {
                    return i; // Return the NFT ID of the winner
                }
            }
        }

        revert("No winner found"); // This should never happen if there is at least one eligible user
    }

    // Function to see how much is staked by users, seperated by stakingStatus
    function getTotalStakedAmounts() public view returns (uint, uint) {
        uint totalStakingAmount = 0;
        uint totalUnstaking = 0;

        // Calculate the cumulative staking amounts of users with stakingStatus set to true
        for (uint i = 0; i < nftTokenAddress.getNextTokenID(); i++) {
            if (users[i].stakingStatus) {
                totalStakingAmount += users[i].stakingAmount;
            } else {
                totalUnstaking += users[i].stakingAmount;
            }
        }
        return (totalStakingAmount, totalUnstaking);
    } 

    function getDailyWinningAmount() public view returns (uint) {
        (uint winningAmount, uint UNUSED) = getTotalStakedAmounts();
        return calculateDailyWinningAmount(winningAmount);
    }
 
    function getWeeklyWinningAmount() public view returns (uint) {
        (uint winningAmount, uint UNUSED) = getTotalStakedAmounts();
        return calculateWeeklyWinningAmount(winningAmount);
    } 

    function calculateDailyWinningAmount(uint inputAmount) internal view returns (uint) {
        return (inputAmount * payoutPercent) / (365 * 200); // Half day's rewards
    }

    function calculateWeeklyWinningAmount(uint inputAmount) internal view returns (uint) {
        return (inputAmount * payoutPercent) / (365 * 25);// Full day's rewards plus 6 half day rewards. 
    } 

    function isReadyToDraw() public view returns (bool) {
        return checkTimestamp(winnerTimestamp) >= 1 days; 
    } 
    function checkTimestamp(uint timestamp) public view returns (uint) {
        return block.timestamp - timestamp;
    }

    function isWeekReward() public view returns (bool) {
        return (dayCounter % 7) == 0; 
    } 

    function setPayoutPercent(uint _payoutPercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        payoutPercent = _payoutPercent;
    }

    function getUserByNFTID(uint _tokenID) public view returns (User memory) {
        User memory user = users[_tokenID];
        return user;
    }

    function giveBronzeRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(BRONZE_ACCESS, contractAddress);
    }

    /*///////////////////////////////////////////////////////////////
                            Interface Functions
            -----------------------------------------------------
                        INFTContract Required Functions
    //////////////////////////////////////////////////////////////*/

    // INFTContract required function 
    function getNextTokenID() external view override returns (uint) {
        return nftTokenAddress.getNextTokenID();
    }

    function _MintTo(address _to, string memory _tokenURI) external override {
        nftTokenAddress._MintTo(_to, _tokenURI);
    }
 
    function burn(uint256 _tokenID) external override {
        nftTokenAddress.burn(_tokenID); 
    }

    function getBurnedTokens() external view override returns (bool[] memory) {
        return nftTokenAddress.getBurnedTokens();
    }

    function _OwnerOf(uint256 tokenID) external view override returns (address) {
        return nftTokenAddress._OwnerOf(tokenID);
    }

    function _Approve(address operator, uint tokenID) external override {
        nftTokenAddress._Approve(operator, tokenID);
    }

    function isApproved(address operator, uint tokenID) external view virtual returns (bool){
       return nftTokenAddress.isApproved(operator, tokenID);
    }
    /*///////////////////////////////////////////////////////////////
                            Interface Functions
            -----------------------------------------------------
                        Ownable Required Functions
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns whether owner can be set in the given execution context.
    function _canSetOwner() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }
}