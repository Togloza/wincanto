// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";

/* UNCOMMENT FOR TURNSTILE REWARDS
interface Turnstile {
    function register(address) external returns (uint256);
    function withdraw(uint256 _tokenId, address _recipient, uint256 _amount) external returns (uint256);
    function balances(uint256 _tokenId) external view returns (uint256);
}
*/

contract NFTContract is ERC721Base, Permissions  {
    // CSR rewards 
    /* UNCOMMENT FOR TURNSTILE REWARDS
    Turnstile immutable turnstile;
    uint public immutable turnstileTokenId;
    */
    address csrRewardWallet;



    // mapping(uint => address) nftOwners;
    mapping(uint => bool) burnedTokens; 

    bytes32 public constant MINTER = keccak256("MINTER_ROLE");
    bytes32 public constant SAFETY_ADDRESS = keccak256("SAFETY_ADDRESS_ROLE");
      constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    )
        ERC721Base(
            _name,
            _symbol,
            _royaltyRecipient,
            _royaltyBps
        )
    {
        csrRewardWallet = _royaltyRecipient;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SAFETY_ADDRESS, msg.sender);
        /* UNCOMMENT FOR TURNSTILE REWARDS
        turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
        turnstileTokenId = turnstile.register(tx.origin);
        */
    }

    function giveMintRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(MINTER, contractAddress);
    }

    function giveSafteyRole(address walletAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(SAFETY_ADDRESS, walletAddress);
    }
   
    function _MintTo(address _to, string memory _tokenURI) external virtual {
        super.mintTo(_to, _tokenURI);
    }



    function _Approve(address operator, uint tokenID) external {
        require(isApprovedOrOwner(operator, tokenID));
        super.approve(operator, tokenID);
    }

    function isApproved(address operator, uint tokenID) external view virtual returns (bool){
        return isApprovedOrOwner(operator, tokenID);
    }
  
    function getNextTokenID() public view virtual returns (uint) {
        return nextTokenIdToMint();
    }
     
    function burn(uint256 _tokenID) external virtual override {
        burnedTokens[_tokenID] = true;
        super._burn(_tokenID, true);
    }
 
    function getBurnedTokens() external view returns (bool[] memory){
        bool[] memory burnedTokensArray = new bool[](getNextTokenID());
            for (uint i = 0; i < getNextTokenID(); i++){
                burnedTokensArray[i] = burnedTokens[i];
            }
        return burnedTokensArray;
    } 

    function _canMint() internal view override returns (bool) { 
        return super.hasRole(MINTER, msg.sender);
    }

    function _OwnerOf(uint256 tokenID) external view virtual returns (address) {
        return super.ownerOf(tokenID);
    }



    
    /*///////////////////////////////////////////////////////////////
                            Turnstile Functions
    //////////////////////////////////////////////////////////////*/
    event csrWithdrawn(uint csrBalance, string whichCSR);
    event tokenTurnstileId(uint tokenId);
 
    // Withdraw CSR rewards to the contract
    // Updates totalPool and rewardBalance variables

    /* UNCOMMENT FOR TURNSTILE REWARDS
    function WithdrawCSR() external payable onlyRole(SAFETY_ADDRESS) {
        uint csrBalance = turnstile.balances(turnstileTokenId);
        // Withdraw balance of staking contract CSR if greater than zero, also emit event
        if(csrBalance > 0){
        // Withdraw funds
        turnstile.withdraw(turnstileTokenId, payable(csrRewardWallet), csrBalance); 
        
        emit csrWithdrawn(csrBalance, "Staking Contract");
        } 
 

    }

    // See current CSR rewards unclaimed
    function CheckCSR() external view onlyRole(SAFETY_ADDRESS) returns (uint) {
        return turnstile.balances(turnstileTokenId);
    }
    */
 
}
