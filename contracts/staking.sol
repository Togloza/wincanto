// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// Import relevant contracts
import "@thirdweb-dev/contracts/openzeppelin-presets/security/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/Ownable.sol";

// Interface for ERC721 contract.
interface INFTContract {
    function getNextTokenID() external view returns (uint);

    function mintTo(address _to, string memory _tokenURI) external;

    function burn(uint256 _tokenID) external;

    function proxyOwnerOf(uint256 tokenID) external view returns (address);

    function getBurnedTokens() external view returns (bool[] memory);

    function proxyIsApprovedOrOwner(
        address _operator,
        uint256 _tokenID
    ) external view returns (bool);
}

contract staking is Ownable, ReentrancyGuard, INFTContract {
    /*///////////////////////////////////////////////////////////////
                        Global Variables
    //////////////////////////////////////////////////////////////*/
    // Unstake time required by the CANTO network.
    //uint constant UNSTAKE_TIME = 21 days;
    uint constant UNSTAKE_TIME = 21 minutes;
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
        uint initialTimestamp; // Currently unused, but may implement in the future.
    }

    /*///////////////////////////////////////////////////////////////
                        Mappings
    //////////////////////////////////////////////////////////////*/
    // Mapping the nft id to variables.
    mapping(uint => User) public users;
    mapping(uint => uint) public unstakeTimestamp;
    mapping(uint => string) public tokenURIs;
    mapping(uint => string) public metadata;

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
        // Mint the token to the sender using the generated URI.
        nftTokenAddress.mintTo(msg.sender, tokenURIs[tokenID]);
    }

    // Function checks if the sender is permitted to send the token, and that it isn't already being unstaked.
    // Otherwise, store the unstake time, and set stakingStatus to false.
    // This removes elegibility for calculateWinningNFTID
    function startUnstake(uint tokenID) public {
        require(
            nftTokenAddress.proxyIsApprovedOrOwner(msg.sender, tokenID),
            "Not owner of token"
        );
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

        unstakeTimestamp[tokenID] = block.timestamp;
        users[tokenID].stakingStatus = false;

        updateMetadata(tokenID); 
        emit startedUnstaking(tokenID, users[tokenID].stakingAmount, block.timestamp);
    }

    function checkValidUnstakingAll() external view returns (uint[] memory, uint[] memory) {
        uint[] memory storeValues = new uint[](
            nftTokenAddress.getNextTokenID()
        );
        uint[] memory storeAmounts = new uint[](
            nftTokenAddress.getNextTokenID()
        );
        uint count = 0; // Counter for non-zero values

        for (uint i = 0; i < nftTokenAddress.getNextTokenID(); i++) {
            //if (unstakeTimestamp[i] != 0 && checkTimestamp(unstakeTimestamp[i]) >= UNSTAKE_TIME) {
            if (isValidUnstake(i)) {
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

    function ownerUnstake(uint tokenID) public payable {
        require(isValidUnstake(tokenID), "Not valid token to unstake");
        require(msg.value == users[tokenID].stakingAmount, "msg.value not equal to stakingAmount");
        require(nftTokenAddress.proxyIsApprovedOrOwner(address(this), tokenID), "Not approved");
        address tokenHolder = nftTokenAddress.proxyOwnerOf(tokenID);
        nftTokenAddress.burn(tokenID);
        payable(tokenHolder).transfer(msg.value);
    }

    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                        Calculating Winner Functions
    //////////////////////////////////////////////////////////////*/

    // Generate a random number using current blockchain data and a random input.
    function generateRandomNumber(uint256 input) internal view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.number, input))
        );
        return randomNumber;
    }

    function findWinningNFTAddress() public view returns (address) {
        uint winningID = calculateWinningNFTID();
        address winner = nftTokenAddress.proxyOwnerOf(winningID);

        // emit winnerChosen(winner, users[winningID].stakingAmount);
        return winner;
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

    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                    Token URI and Metadata Functions
    //////////////////////////////////////////////////////////////*/
    function setTokenURI(uint256 tokenID) public {
        string memory baseURI = "https://example.com/api/token/";

        updateMetadata(tokenID);

        // Set the token's metadata URI
        string memory tokenURI = string(
            abi.encodePacked(baseURI, uint256ToString(tokenID))
        );
        tokenURIs[tokenID] = tokenURI;

        // Store the metadata
        //_setTokenURI(tokenID, metadata);
    }

    function getMetadata(uint tokenID) public view returns (string memory) {
        string memory tokenMetadata = metadata[tokenID];
        return tokenMetadata;
    }

    function updateMetadata(uint tokenID) public {
        User memory user = getUserByNFTID(tokenID);
        // Convert the struct values to string
        string memory stakingAmountStr = uint256ToString(user.stakingAmount);
        string memory stakingStatusStr = boolToString(user.stakingStatus);
        string memory initialTimestampStr = uint256ToString(user.initialTimestamp);

        // Construct the metadata JSON object
        metadata[tokenID] = string(
            abi.encodePacked(
                "{",
                '"stakingAmount": "',
                stakingAmountStr,
                '",',
                '"stakingStatus": "',
                stakingStatusStr,
                '",',
                '"initialTimestamp": "',
                initialTimestampStr,
                '"',
                "}"
            )
        );

    }

    /*///////////////////////////////////////////////////////////////
                        Helper Functions
        -----------------------------------------------------
                        Timestamp Functions
    //////////////////////////////////////////////////////////////*/
    function checkTimestamp(uint initialTimestamp) internal view returns (uint) {
        return block.timestamp - initialTimestamp;
    }

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

    function hexToDecimal(string memory hexString) public pure returns (uint256) {
        uint256 decimalValue = 0;
        uint256 digitValue;
        
        for (uint256 i = 0; i < bytes(hexString).length; i++) {
            uint8 charCode = uint8(bytes(hexString)[i]);
            
            if (charCode >= 48 && charCode <= 57) {
                digitValue = charCode - 48;
            } else if (charCode >= 65 && charCode <= 70) {
                digitValue = charCode - 55;
            } else if (charCode >= 97 && charCode <= 102) {
                digitValue = charCode - 87;
            } else {
                revert("Invalid hex string");
            }
            
            decimalValue = decimalValue * 16 + digitValue;
        }
        
        return decimalValue;
    }

    /*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Getter Functions
    //////////////////////////////////////////////////////////////*/

    function getUserByNFTID(uint _tokenID) public view returns (User memory) {
        User memory user = users[_tokenID];
        return user;
    }

    // Function to see how much is staked by users, seperated by stakingStatus
    function getTotalStakedAmounts() external view returns (uint, uint) {
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

    function getContractBalance() external view returns (uint){
        return address(this).balance;
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

    // Function to withdraw tokens in case tokens are locked in the contract.
    function WithdrawTokens(uint _amount) external virtual onlyOwner {
        require(
            address(this).balance >= _amount,
            "Not enough tokens in contract"
        );

        payable(msg.sender).transfer(_amount);
    }

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event receivedFunds(address sender, uint _amount);
    event winnerChosen(address winner, uint stakedAmount);
    event startedUnstaking(uint tokenID, uint unstakingAmount, uint timestamp);

    /*///////////////////////////////////////////////////////////////
                            Interface Functions
            -----------------------------------------------------
                        INFTContract Required Functions
    //////////////////////////////////////////////////////////////*/

    // INFTContract required function
    function getNextTokenID() external view override returns (uint) {
        return nftTokenAddress.getNextTokenID();
    }

    function mintTo(address _to, string memory _tokenURI) external override {
        nftTokenAddress.mintTo(_to, _tokenURI);
    }

    function burn(uint256 _tokenID) external override {
        nftTokenAddress.burn(_tokenID);
    }

    function getBurnedTokens() external view override returns (bool[] memory) {
        return nftTokenAddress.getBurnedTokens();
    }

    function proxyOwnerOf(uint256 tokenID) external view override returns (address) {
        return nftTokenAddress.proxyOwnerOf(tokenID);
    }

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenID) external view override returns (bool) {
        return nftTokenAddress.proxyIsApprovedOrOwner(_operator, _tokenID);
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
