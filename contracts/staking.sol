// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// Import relevant contracts
import "@thirdweb-dev/contracts/openzeppelin-presets/security/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/Ownable.sol";



// Interface for ERC721 contract to get tokenId values. 
interface INFTContract {
    function getNextTokenId() external view returns (uint);
    function mintTo(address _to, string memory _tokenURI) external;
    function burn(uint256 _tokenId) external;

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenId) 
    external 
    view  
    returns (bool isApprovedOrOwnerOf);
} 


contract staking is Ownable, ReentrancyGuard, INFTContract {

/*///////////////////////////////////////////////////////////////
                        Global Variables
    //////////////////////////////////////////////////////////////*/
// Unstake time required by the CANTO network.
uint constant UNSTAKE_TIME = 21 days;

// Owner's address.
address private _owner;

// Initialize ERC721 token address.
INFTContract nftTokenAddress; 

/*///////////////////////////////////////////////////////////////
                        Structures
    //////////////////////////////////////////////////////////////*/
// Struct to hold user information. 
struct User {
    uint stakingAmount;
    bool stakingStatus;
    uint initialTimestamp;
}

/*///////////////////////////////////////////////////////////////
                        Mappings
    //////////////////////////////////////////////////////////////*/
// Mapping the nft id to the user structure variable.
mapping(uint => User) public users;
mapping(uint => uint) public unstakeTimestamp;
mapping(uint => string) public tokenURIs;
mapping(uint => address) public addresses;  

/*///////////////////////////////////////////////////////////////
                        Constructor
    //////////////////////////////////////////////////////////////*/
constructor(INFTContract _nftTokenAddress) {
    require(address(_nftTokenAddress) != address(0), "address 0");

    nftTokenAddress = _nftTokenAddress; 

    _setupOwner(msg.sender);
}


/*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Staking Logic
    //////////////////////////////////////////////////////////////*/

function stake() public payable {
    uint _stakingAmount = _msgValue(); 

    // Create a new User struct instance
    User memory newUser = User({
        stakingAmount: _stakingAmount,
        stakingStatus: true,
        initialTimestamp: block.timestamp
    });

    // Add the new user to the mapping using the NFT ID as the key
    users[nftTokenAddress.getNextTokenId()] = newUser;
    // Add the address to the addresses mapping with the NFT ID as the key
    addresses[nftTokenAddress.getNextTokenId()] = msg.sender;

    // Get the next token id from the ERC721 contract
    uint256 tokenId = nftTokenAddress.getNextTokenId();
    // Dynamically generate the URI data 
    setTokenURI(tokenId);
    // Mint the token to the sender using the generated URI.
    nftTokenAddress.mintTo(msg.sender, tokenURIs[tokenId]);
    

}

// Function checks if the sender is permitted to send the token, and that it isn't already being unstaked.
// Otherwise, store the unstake time, and set stakingStatus to false. 
// This removes elegibility for calculateWinningNFTID
function startUnstake(uint nftID) public {
    require(nftTokenAddress.proxyIsApprovedOrOwner(msg.sender, nftID), "Not owner of token");
    if (unstakeTimestamp[nftID] != 0){
        revert(string(abi.encodePacked("Unstaking already in process, seconds since unstake: ", uint256ToString(checkTimestamp(unstakeTimestamp[nftID])))));
    }

    unstakeTimestamp[nftID] = block.timestamp;
    users[nftID].stakingStatus = false;
    emit startedUnstaking(nftID, users[nftID].stakingAmount, block.timestamp);
} 

function checkValidUnstaking() external view returns (uint[] memory, uint[] memory) {
    uint[] memory storeValues = new uint[](nftTokenAddress.getNextTokenId());
    uint[] memory storeAmounts = new uint[](nftTokenAddress.getNextTokenId());
    uint count = 0; // Counter for non-zero values

    for (uint i = 0; i < nftTokenAddress.getNextTokenId(); i++) {
        if (unstakeTimestamp[i] != 0 && checkTimestamp(unstakeTimestamp[i]) >= UNSTAKE_TIME) {
            storeValues[count] = i;
            storeAmounts[count] = users[i].stakingAmount;
            count++;
        }
    }

    // Create new arrays with only non-zero values
    uint[] memory nonZeroStoreValues = new uint[](count);
    uint[] memory nonZeroStoreAmounts = new uint[](count);
    for (uint j = 0; j < count; j++) {
        nonZeroStoreValues[j] = storeValues[j];
        nonZeroStoreAmounts[j] = storeAmounts[j];
    }

    return (nonZeroStoreValues, nonZeroStoreAmounts);
}

function ownerUnstake(uint nftID) public payable{

     
}


/*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Calculating Winner Functions
    //////////////////////////////////////////////////////////////*/

// Generate a random number using current blockchain data and a random input.
function generateRandomNumber(uint256 input) internal view returns (uint256) {
    uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.number, input)));
    return randomNumber;
} 

function findWinningNFTAddress() public view returns(address) {
    uint winningID = calculateWinningNFTID();
    address winner = addresses[winningID];

    // emit winnerChosen(winner, users[winningID].stakingAmount);
    return winner;
}

// Function to calculate the ID of the winning NFTID. 
// Chances of winning are proportional to the amount staked by the users.
// Only NFTs with stakingStatus true are counted.
function calculateWinningNFTID() internal view returns (uint) {
    uint totalStakingAmount = 0;

    // Calculate the cumulative staking amounts of users with stakingStatus set to true
    for (uint i = 0; i < nftTokenAddress.getNextTokenId(); i++) {
        if (users[i].stakingStatus) {
            totalStakingAmount += users[i].stakingAmount;
        }
    }

    // Generate a random number within the range of the cumulative staking amounts
    uint randomNum = generateRandomNumber(totalStakingAmount) % totalStakingAmount;

    // Find the winner by iterating over the users and checking the cumulative staking amounts
    uint cumulativeAmount = 0;
    for (uint i = 0; i < nftTokenAddress.getNextTokenId(); i++) {
        if (users[i].stakingStatus) {
            cumulativeAmount += users[i].stakingAmount;
            if (randomNum <= cumulativeAmount) {
                return i; // Return the NFT ID of the winner
            }
        }
    }

    revert("No winner found"); // This should never happen if there is at least one eligible user
}

/*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                    Token URI and Metadata Functions
    //////////////////////////////////////////////////////////////*/
function setTokenURI(uint256 tokenId) public {
    string memory baseURI = "https://example.com/api/token/";
    User memory user = getUserByNFTID(tokenId);
    // Convert the struct values to string
    string memory stakingAmountStr = uint256ToString(user.stakingAmount);
    string memory stakingStatusStr = boolToString(user.stakingStatus);
    string memory initialTimestampStr = uint256ToString(user.initialTimestamp);

    // Construct the metadata JSON object
    string memory metadata = string(
        abi.encodePacked(
            "{",
            '"stakingAmount": "', stakingAmountStr, '",',
            '"stakingStatus": "', stakingStatusStr, '",',
            '"initialTimestamp": "', initialTimestampStr, '"',
            "}"
        )
    );

    // Set the token's metadata URI
    string memory tokenURI = string(abi.encodePacked(baseURI, uint256ToString(tokenId)));
    tokenURIs[tokenId] = tokenURI;

    // Store the metadata
    //_setTokenURI(tokenId, metadata);
}


/*///////////////////////////////////////////////////////////////
                        Helper Functions
        -----------------------------------------------------
                        Timestamp Functions
    //////////////////////////////////////////////////////////////*/
function checkTimestamp(uint initialTimestamp) internal view returns (uint) {
    return block.timestamp - initialTimestamp; 
}


/*///////////////////////////////////////////////////////////////
                        Helper Functions
        -----------------------------------------------------
                        Conversion Functions
    //////////////////////////////////////////////////////////////*/

// Helper function to convert addresses to strings
function addressToString(address _address) internal pure returns (string memory) {
    bytes32 value = bytes32(uint256(uint160(_address)));
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(42);
    str[0] = "0";
    str[1] = "x";
    for (uint256 i = 0; i < 20; i++) {
        str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
        str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
    }

    return string(str);
}

// Helper function to convert uint256 to string
function uint256ToString(uint256 _value) internal pure returns (string memory) {
    if (_value == 0) {
        return "0";
    }

    uint256 length;
    uint256 temp = _value;
    while (temp != 0) {
        length++;
        temp /= 10;
    }

    bytes memory buffer = new bytes(length);
    while (_value != 0) {
        length -= 1;
        buffer[length] = bytes1(uint8(48 + (_value % 10)));
        _value /= 10;
    }

    return string(buffer);
}

// Helper function to convert bool to string
function boolToString(bool _value) internal pure returns (string memory) {
    return _value ? "true" : "false";
}

/*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Getter Functions
    //////////////////////////////////////////////////////////////*/


function getUserByNFTID(uint _nftID) public view returns (User memory) {
    User memory user = users[_nftID];
    return user;
}

// Function to see how much is staked by users, seperated by stakingStatus
function totalStakedAmounts() external view returns(uint, uint){

    uint totalStakingAmount = 0;
    uint totalUnstaking = 0;

    // Calculate the cumulative staking amounts of users with stakingStatus set to true
    for (uint i = 0; i < nftTokenAddress.getNextTokenId(); i++) {
        if (users[i].stakingStatus) {
            totalStakingAmount += users[i].stakingAmount;
        }
        else {
            totalUnstaking += users[i].stakingAmount;
        }
    }
    return (totalStakingAmount, totalUnstaking);
}  
/*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Utility Functions
    //////////////////////////////////////////////////////////////*/
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgValue() internal view returns (uint) {
        return msg.value;
    }


    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event receivedFunds(address sender, uint _amount);
    event winnerChosen(address winner, uint stakedAmount);
    event startedUnstaking(uint nftID, uint unstakingAmount, uint timestamp);


    /*///////////////////////////////////////////////////////////////
                            Interface Functions
            -----------------------------------------------------
                        INFTContract Required Functions
    //////////////////////////////////////////////////////////////*/


    // INFTContract required function
    function getNextTokenId() external view returns (uint) {
        return nftTokenAddress.getNextTokenId();
    }

    function mintTo(address _to, string memory _tokenURI) external override {
        nftTokenAddress.mintTo(_to, _tokenURI);
    }
    function burn(uint256 _tokenId) external override {
        nftTokenAddress.burn(_tokenId);
    }

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenId) 
    external 
    view 
    override
    returns (bool isApprovedOrOwnerOf){
        return nftTokenAddress.proxyIsApprovedOrOwner(_operator, _tokenId);
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
        address payable account = payable(owner());
        account.transfer(msg.value);
        emit receivedFunds(msg.sender, msg.value);
    }




}