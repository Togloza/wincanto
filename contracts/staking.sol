// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// Import relevant contracts
import "@thirdweb-dev/contracts/openzeppelin-presets/security/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/Ownable.sol";


// Interface for ERC721 contract to get tokenId values. 
interface INFTContract {
    function getNextTokenId() external view returns (uint);
}


contract staking is Ownable, ReentrancyGuard, INFTContract {


address private _owner;
INFTContract nftTokenAddress; 


// Struct to hold user information. 
struct User {
    address userAddress;
    uint stakingAmount;
    bool stakingStatus;
    uint timestamp;
}

mapping(uint => User) public users;
mapping(uint => string) public tokenURIs; 

constructor(INFTContract _nftTokenAddress) {
    require(address(_nftTokenAddress) != address(0), "address 0");

    nftTokenAddress = _nftTokenAddress; 

    _setupOwner(msg.sender);
}

function generateRandomNumber(uint256 input) external view onlyOwner returns (uint256) {
    uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, block.number, input)));
    return randomNumber;
}

function setTokenURI(uint256 tokenId, string memory variableData) internal {
    string memory baseURI = "https://example.com/api/token/";

    // Construct the complete metadata URI with the variable data
    string memory tokenURI = string(abi.encodePacked(baseURI, uint256ToString(tokenId), "?variable=", variableData));

    tokenURIs[tokenId] = tokenURI;
}



function getUserByNFTID(uint _nftID) public view returns (User memory) {
    User memory user = users[_nftID];
    require(user.userAddress != address(0), "User not found");
    
    return user;
}

function stake(uint _stakingAmount) public {
    // Create a new User struct instance
    User memory newUser = User({
        userAddress: msg.sender,
        stakingAmount: _stakingAmount,
        stakingStatus: true,
        timestamp: block.timestamp
    });
    
    // Add the new user to the mapping using the NFT ID as the key
    users[nftTokenAddress.getNextTokenId()] = newUser;
    
    // Mint the ERC721 token with the _nftID
    // ...
}







function setTokenURI(uint256 tokenId) internal {
    string memory baseURI = "https://example.com/api/token/";
    User memory user = getUserByNFTID(tokenId);
    // Convert the struct values to string
    string memory userAddressStr = addressToString(user.userAddress);
    string memory stakingAmountStr = uint256ToString(user.stakingAmount);
    string memory stakingStatusStr = boolToString(user.stakingStatus);
    string memory timestampStr = uint256ToString(user.timestamp);

    // Construct the complete metadata URI with the struct values
    string memory tokenURI = string(
        abi.encodePacked(
            baseURI,
            uint256ToString(tokenId),
            "?userAddress=",
            userAddressStr,
            "&stakingAmount=",
            stakingAmountStr,
            "&stakingStatus=",
            stakingStatusStr,
            "&timestamp=",
            timestampStr
        )
    );

    tokenURIs[tokenId] = tokenURI;
}

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
                                Events
    //////////////////////////////////////////////////////////////*/

    event receivedFunds(address sender, uint _amount);


    /*///////////////////////////////////////////////////////////////
                            Interface Functions
    //////////////////////////////////////////////////////////////*/



    function getNextTokenId() external view returns (uint) {
        return nftTokenAddress.getNextTokenId();
    }

    /// @dev Returns whether owner can be set in the given execution context.
    function _canSetOwner() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }



    /*///////////////////////////////////////////////////////////////
                            Contract Functions
    //////////////////////////////////////////////////////////////*/
    receive() external payable {
        address payable account = payable(owner());
        account.transfer(msg.value);
        emit receivedFunds(msg.sender, msg.value);
    }




}