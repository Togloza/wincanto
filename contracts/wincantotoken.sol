// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";


contract NFTContract is ERC721Base, Permissions  {

    // mapping(uint => address) nftOwners;
    mapping(uint => bool) burnedToken; 

    bytes32 public constant MINTER = keccak256("MINTER_ROLE");
    uint public number;
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


 
    function proxyMintTo(address _to, string memory _tokenURI) external virtual {
    //    nftOwners[nextTokenIdToMint()] = msg.sender; 
        super.mintTo(_to, _tokenURI);
    }

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenId) 
    external 
    view
    virtual  
    returns (bool) {
        return super.isApprovedOrOwner(_operator, _tokenId);
    }

    function getNextTokenId() public view virtual returns (uint) {
        return nextTokenIdToMint();
    }
    
    function burn(uint256 _tokenId) external virtual override {
        burnedToken[_tokenId] = true;
        super._burn(_tokenId, true);
    }

/*    function safeTransferFrom( 
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyAllowedOperator(from) {
        nftOwners[tokenId] = to; 
        super.safeTransferFrom(from, to, tokenId);
    }  
*/

    function proxyOwnerOf(uint256 tokenId) external view virtual returns (address) {
        return super.ownerOf(tokenId);
    }
 
}
