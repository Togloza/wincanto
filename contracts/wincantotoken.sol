// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";


contract NFTContract is ERC721Base, Permissions  {

    mapping(uint => address) nftOwners; 

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



    function proxyMintTo(address _to, string memory _tokenURI) external {
        nftOwners[nextTokenIdToMint()] = msg.sender; 
        super.mintTo(_to, _tokenURI);
    }

    function proxyIsApprovedOrOwner(address _operator, uint256 _tokenId) 
    external 
    view  
    returns (bool isApprovedOrOwnerOf) {
        return super.isApprovedOrOwner(_operator, _tokenId);
    }
 







    function getNextTokenId() public view returns (uint) {
        return nextTokenIdToMint();
    }
    
    function burn(uint256 _tokenId) external override {
        super._burn(_tokenId, true);
    }




}
