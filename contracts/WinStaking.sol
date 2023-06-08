// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;


import "./IWinToken.sol";  
import "./WinnerCalculator.sol";
import "./ConversionHelper.sol";
import "./Metadata.sol";
 
/* UNCOMMENT FOR TURNSTILE REWARDS
interface Turnstile {
function assign(uint256 _tokenId) external returns (uint256);
} 
*/

contract WinStaking is IWinToken, WinnerCalculator, ConversionHelper, Metadata {
    /*///////////////////////////////////////////////////////////////
                        Global Variables
    //////////////////////////////////////////////////////////////*/
    // Turnstile required for CSR rewards
    /* UNCOMMENT FOR TURNSTILE REWARDS
    Turnstile immutable turnstile;
    */

    // Unstake time required by the CANTO network.
    //uint constant UNSTAKE_TIME = 21 days;
    uint constant UNSTAKE_TIME = 5 minutes;
    // Owner's address. 
    address private _owner;

    // Access roles
 
    bytes32 public constant SILVER_ACCESS = keccak256("SILVER_ACCESS_ROLE");

    // Mapping tokenID to when users started to unstake
    mapping(uint => uint) public unstakeTimestamp;

    

    /*///////////////////////////////////////////////////////////////
                        Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(IWinToken _nftTokenAddress) {
        require(address(_nftTokenAddress) != address(0), "address 0");

        nftTokenAddress = _nftTokenAddress; 
 
        _setupOwner(msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SILVER_ACCESS, msg.sender);


        // Required for CSR rewards
        /* UNCOMMENT FOR TURNSTILE REWARDS
        turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
        turnstile.assign(csrTokenID);
        */

    } 

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event receivedFunds(address sender, uint _amount);
    event startedUnstaking(uint tokenID, uint unstakingAmount, uint timestamp);
    event depositedTokens(uint depositAmount, address sender, uint timestamp);
    event rewardsClaimed(address winnerAddress, uint rewardAmount);


    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Staking Logic
    //////////////////////////////////////////////////////////////*/

    // Staking function, creates new user, set tokenURI and metadata, and mint NFT to sender.
    function stake() public payable {
        require(msg.value >= 0, "Staking 0 tokens");
        // Create a new User struct instance
        User memory newUser = User({
            stakingAmount: msg.value,
            stakingStatus: true,
            initialTimestamp: block.timestamp
        });

        // Add the new user to the mapping using the NFT ID as the key
        users[nftTokenAddress.getNextTokenID()] = newUser;

        // Get the next token id from the ERC721 contract
        uint256 tokenID = nftTokenAddress.getNextTokenID();
        // Dynamically generate the URI data
        setTokenURI(tokenID);
        updateMetadata(tokenID);
        // Mint the token to the sender using the generated URI.
        nftTokenAddress._MintTo(msg.sender, tokenURIs[tokenID]);
    } 

    // Function checks if the sender is permitted to send the token, and that it isn't already being unstaked.
    // Otherwise, store the unstake time, and set stakingStatus to false.
    // This removes elegibility for calculateWinningNFTID
    function startUnstake(uint tokenID, address sender) public {
        require(nftTokenAddress._OwnerOf(tokenID) == msg.sender, "Not owner of token");
        // If already unstaking, revert and send message.
        if (unstakeTimestamp[tokenID] != 0) {
            revert(
                string(
                    abi.encodePacked(
                        "Unstaking already in process, seconds since unstake: ",
                        uint256ToString(checkTimestamp(unstakeTimestamp[tokenID]))
                    )
                )
            );
        }
        // Set unstakeTimestamp to current time, and set stakingStatus to false.
        unstakeTimestamp[tokenID] = block.timestamp;
        users[tokenID].stakingStatus = false;
        // Update the metadata to reflect the staking status and emit event.
        updateMetadata(tokenID); 
        emit startedUnstaking(tokenID, users[tokenID].stakingAmount, block.timestamp);
    }

    // Calculate how much is staked and in the process of unstaking
    function checkValidUnstakingAll() external view onlyRole(SILVER_ACCESS) returns (uint[] memory, uint[] memory) {
        uint[] memory storeID = new uint[](nftTokenAddress.getNextTokenID());
        uint[] memory storeAmounts = new uint[](nftTokenAddress.getNextTokenID());
        uint count = 0; // Counter for non-zero values

        for (uint i = 0; i < nftTokenAddress.getNextTokenID(); i++) {
            if (isValidUnstake(i)) {
                storeID[count] = i;
                storeAmounts[count] = users[i].stakingAmount;
                count++;
            }
        }

        // Create new arrays with only non-zero values
        uint[] memory nonZeroStoreID = new uint[](count);
        uint[] memory nonZeroStoreAmounts = new uint[](count);
        for (uint j = 0; j < count; j++) {
            nonZeroStoreID[j] = storeID[j];
            nonZeroStoreAmounts[j] = storeAmounts[j];
        }

        return (nonZeroStoreID, nonZeroStoreAmounts);
    }

    // If isValidUnstake and approved, burn the NFT and send stakingAmount to tokenHolder.
    function Unstake(uint tokenID) public {
        require(isValidUnstake(tokenID), "Not valid token to unstake");
        require(nftTokenAddress.isApproved(address(this), tokenID), "Contract not approved");
        // Find the owner of the token 
        address tokenHolder = nftTokenAddress._OwnerOf(tokenID);
        uint stakingAmount = users[tokenID].stakingAmount;

        require(address(this).balance >= stakingAmount, "Not enough tokens held in contract at the moment");
        // nftTokenAddress.proxyApproval(address(this), tokenID); Approval required in front end
        // Burn token and transfer funds.
        nftTokenAddress.burn(tokenID); 
         
        payable(tokenHolder).transfer(stakingAmount);
    }

    
    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Reward Functions
    //////////////////////////////////////////////////////////////*/

    function checkRewards() public view returns (uint){
        return winnerRewards[msg.sender]; 
    }
    function claimRewards() public {
        uint userRewards = winnerRewards[msg.sender];
        require(userRewards >= 0, "No rewards claimable");
        // Reset user rewards, send rewards, emit event.
        winnerRewards[msg.sender] = 0;
        assert(totalRewards >= userRewards);
        totalRewards -= userRewards;
        payable(msg.sender).transfer(userRewards);
        emit rewardsClaimed(msg.sender, userRewards);
    }
    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Access Functions
    //////////////////////////////////////////////////////////////*/
    function giveSilverRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(SILVER_ACCESS, contractAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        Helper Functions
        -----------------------------------------------------
                        Timestamp Functions
    //////////////////////////////////////////////////////////////*/
 
    function isValidUnstake(uint tokenID) internal view returns (bool) {
        bool[] memory burnedTokens = nftTokenAddress.getBurnedTokens();

        if (
            users[tokenID].stakingStatus == false &&
            checkTimestamp(unstakeTimestamp[tokenID]) >= UNSTAKE_TIME &&
            burnedTokens[tokenID] == false
        ) {
            return true;
        } else {
            return false;
        }
    }

    /*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Getter Functions
    //////////////////////////////////////////////////////////////*/


    function getContractBalance() external view returns (uint){
        return address(this).balance;
    }

    /*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Utility Functions
    //////////////////////////////////////////////////////////////*/

    // Function to withdraw tokens in case tokens are locked in the contract.
    function WithdrawTokens(uint _amount) external {
        require(msg.sender == owner(), "Not owner");
        require(address(this).balance >= _amount, "Not enough tokens in contract");

        payable(msg.sender).transfer(_amount);
    }

    function DepositTokens() external payable {
        emit depositedTokens(msg.value, msg.sender, block.timestamp);
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

    /*///////////////////////////////////////////////////////////////
                            Contract Functions
    //////////////////////////////////////////////////////////////*/

    // If the contract receives eth with transfer, send to owner and emit event.
    receive() external payable {
        emit receivedFunds(msg.sender, msg.value);
    }
}
