// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// Import relevant contracts
import "@thirdweb-dev/contracts/openzeppelin-presets/security/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/Ownable.sol";

// Interface for ERC721 contract.
interface INFTContract {
    function getNextTokenID() external view returns (uint);

    function proxyMintTo(address _to, string memory _tokenURI) external;

    function burn(uint256 _tokenID) external;

    function proxyOwnerOf(uint256 tokenID) external view returns (address);

    function getBurnedTokens() external view returns (bool[] memory);

    function proxyIsApprovedOrOwner(
        address _operator,
        uint256 _tokenID
    ) external view returns (bool);

    function proxyApproval(address operator, uint tokenID) external;
}

contract staking is Ownable, ReentrancyGuard, INFTContract {
    /*///////////////////////////////////////////////////////////////
                        Global Variables
    //////////////////////////////////////////////////////////////*/
    // Unstake time required by the CANTO network.
    //uint constant UNSTAKE_TIME = 21 days;
    uint constant UNSTAKE_TIME = 5 minutes;
    // Owner's address. 
    address private _owner;

    // Total Rewards in contract
    uint public totalRewards;

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
    mapping(address => uint) public winnerRewards;

    /*///////////////////////////////////////////////////////////////
                        Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(INFTContract _nftTokenAddress) {
        require(address(_nftTokenAddress) != address(0), "address 0");

        nftTokenAddress = _nftTokenAddress;

        _setupOwner(msg.sender);
    }


    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event receivedFunds(address sender, uint _amount);
    event winnerChosen(address winner, uint winningAmount);
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
        nftTokenAddress.proxyMintTo(msg.sender, tokenURIs[tokenID]);
    } 

    // Function checks if the sender is permitted to send the token, and that it isn't already being unstaked.
    // Otherwise, store the unstake time, and set stakingStatus to false.
    // This removes elegibility for calculateWinningNFTID
    function startUnstake(uint tokenID) public {
        require(
            nftTokenAddress.proxyIsApprovedOrOwner(msg.sender, tokenID),
            "Not owner of token"
        );
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
    function checkValidUnstakingAll() external view returns (uint[] memory, uint[] memory) {
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
        require(nftTokenAddress.proxyIsApprovedOrOwner(address(this), tokenID), "Contract not approved");
        // Find the owner of the token
        address tokenHolder = nftTokenAddress.proxyOwnerOf(tokenID);
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
                        Calculating Winner Functions
    //////////////////////////////////////////////////////////////*/

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
        address winner = nftTokenAddress.proxyOwnerOf(winningID);
        
        return (winner, winningID);
    }
    // Write function to update contract on winner and amount.
    function publishWinningAddress(address winnerAddress, uint winningAmount) external {
        require(msg.sender == owner()); 
        winnerRewards[winnerAddress] += winningAmount;
        totalRewards += winningAmount;
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
        totalRewards -= userRewards;
        payable(msg.sender).transfer(userRewards);
        emit rewardsClaimed(msg.sender, userRewards);
    }

    /*///////////////////////////////////////////////////////////////
                        Main Functions
        -----------------------------------------------------
                    Token URI and Metadata Functions
    //////////////////////////////////////////////////////////////*/
    function setTokenURI(uint256 tokenID) public {
        string memory baseURI = "https://example.com/api/token/";

        // Set the token's metadata URI
        string memory tokenURI = string(
            abi.encodePacked(baseURI, uint256ToString(tokenID))
        );
        tokenURIs[tokenID] = tokenURI;

        // Store the metadata
        //_setTokenURI(tokenID, metadata);
    }

    function getMetadata(uint tokenID) public view returns (string memory) {
        return metadata[tokenID];
    }

    // This function updates the metadata for changes in the user struct. 
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
    function checkTimestamp(uint timestamp) internal view returns (uint) {
        return block.timestamp - timestamp;
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

    function getTotalRewards() external view returns (uint){
        return totalRewards;
    }

    /*///////////////////////////////////////////////////////////////
                         Helper Functions
        -----------------------------------------------------
                         Utility Functions
    //////////////////////////////////////////////////////////////*/

    // Function to withdraw tokens in case tokens are locked in the contract.
    function WithdrawTokens(uint _amount) external virtual {
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

    function proxyMintTo(address _to, string memory _tokenURI) external override {
        nftTokenAddress.proxyMintTo(_to, _tokenURI);
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

    function proxyApproval(address operator, uint tokenID) external override {
        nftTokenAddress.proxyApproval(operator, tokenID);
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
                            Contract Functions
    //////////////////////////////////////////////////////////////*/

    // If the contract receives eth with transfer, send to owner and emit event.
    receive() external payable {
        emit receivedFunds(msg.sender, msg.value);
    }
}
