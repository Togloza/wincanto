// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IWinToken {
    function getNextTokenID() external view returns (uint);

    function _MintTo(address _to, string memory _tokenURI) external;

    function burn(uint256 _tokenID) external;

    function _OwnerOf(uint256 tokenID) external view returns (address);

    function getBurnedTokens() external view returns (bool[] memory);

    function isApproved(address operator, uint tokenID) external view returns (bool);

    function _Approve(address operator, uint tokenID) external;
}