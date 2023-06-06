// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";


contract NFTContract is ERC721Base, Permissions  {

    // mapping(uint => address) nftOwners;
    mapping(uint => bool) burnedTokens; 

    bytes32 public constant MINTER = keccak256("MINTER_ROLE");
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
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function giveMintRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(MINTER, contractAddress);
    }
  
    function proxyMintTo(address _to, string memory _tokenURI) external virtual {
        super.mintTo(_to, _tokenURI);
    }

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenID) 
    external 
    view
    virtual  
    returns (bool) {
        return super.isApprovedOrOwner(_operator, _tokenID);
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

    function proxyOwnerOf(uint256 tokenID) external view virtual returns (address) {
        return super.ownerOf(tokenID);
    }
 
}
