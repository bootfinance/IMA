pragma solidity ^0.5.0;

import "./Permissions.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Full.sol";

contract LockAndDataForSchainERC721 is Permissions {

    mapping(uint => address) public ERC721Tokens;
    mapping(address => uint) public ERC721Mapper;
    // mapping(uint => uint) public mintToken;

    constructor(address lockAndDataAddress) Permissions(lockAndDataAddress) public {
        
    }

    function sendERC721(address contractHere, address to, uint tokenId) public allow("ERC721Module") returns (bool) {
        if (IERC721Full(contractHere).ownerOf(tokenId) == address(this)) {
            IERC721Full(contractHere).transferFrom(address(this), to, tokenId);
            require(IERC721Full(contractHere).ownerOf(tokenId) == to, "Did not transfer");
        } // else {
        //     //mint!!!
        // }
        return true;
    }

    function addERC721Token(address addressERC721, uint contractPosition) public allow("ERC721Module") {
        ERC721Tokens[contractPosition] = addressERC721;
        ERC721Mapper[addressERC721] = contractPosition;
    }
}