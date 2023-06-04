// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";


contract NFTContract is ERC721Base, Permissions  {
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

    
    function mintTo(address _to, string memory _tokenURI) public override {
        _setTokenURI(nextTokenIdToMint(), _tokenURI);
        _safeMint(_to, 1, "");
    }

    function getNextTokenId() public view returns (uint) {
        return nextTokenIdToMint();
    }


    



}
