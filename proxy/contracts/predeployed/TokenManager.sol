// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   TokenManager.sol - SKALE Interchain Messaging Agent
 *   Copyright (C) 2019-Present SKALE Labs
 *   @author Artem Payvin
 *
 *   SKALE IMA is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   SKALE IMA is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with SKALE IMA.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/IERC721.sol";

import "../interfaces/IMessageProxy.sol";
import "./ERC20ModuleForSchain.sol";
import "./ERC721ModuleForSchain.sol";
import "../Messages.sol";
import "./PermissionsForSchain.sol";



interface ILockAndDataERCOnSchain {
    function getERC20OnSchain(string calldata schainID, address contractOnMainnet) external view returns (address);
    function getERC721OnSchain(string calldata schainID, address contractOnMainnet) external view returns (address);
}

/**
 * This contract runs on schains and accepts messages from main net creates ETH clones.
 * When the user exits, it burns them
 */

/**
 * @title Token Manager
 * @dev Runs on SKALE Chains, accepts messages from mainnet, and instructs
 * TokenFactory to create clones. TokenManager mints tokens via
 * LockAndDataForSchain*. When a user exits a SKALE chain, TokenFactory
 * burns tokens.
 */
contract TokenManager is PermissionsForSchain {

    // ID of this schain,
    string private _chainID;

    uint256 public constant GAS_CONSUMPTION = 2000000000000000;

    modifier rightTransaction(string memory schainID) {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address schainTokenManagerAddress = LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(schainHash);
        require(
            schainHash != keccak256(abi.encodePacked("Mainnet")),
            "This function is not for transferring to Mainnet"
        );
        require(schainTokenManagerAddress != address(0), "Incorrect Token Manager address");
        _;
    }

    modifier receivedEth(uint256 amount) {
        require(LockAndDataForSchain(getLockAndDataAddress()).receiveEth(msg.sender, amount), "Could not receive ETH Clone");
        _;
    }


    /// Create a new token manager

    constructor(
        string memory newChainID,
        address newLockAndDataAddress
    )
        public
        PermissionsForSchain(newLockAndDataAddress)
    {
        _chainID = newChainID;
    }

    function exitToMainWithoutData(address to, uint256 amount) external {
        exitToMain(to, amount);
    }

    function transferToSchainWithoutData(string calldata schainID, address to, uint256 amount) external {
        transferToSchain(schainID, to, amount);
    }

    /**
     * @dev Adds ETH cost to perform exit transaction.
     */
    function addEthCostWithoutAddress(uint256 amount) external {
        addEthCost(amount);
    }

    /**
     * @dev Deducts ETH cost to perform exit transaction.
     */
    function removeEthCost() external {
        revert("Temporarily unimplemented");
    }

    function exitToMainERC20(address contractOnMainnet, address to, uint256 amount) external {
        address lockAndDataERC20 = LockAndDataForSchain(
            getLockAndDataAddress()
        ).getLockAndDataErc20();
        address erc20Module = LockAndDataForSchain(
            getLockAndDataAddress()
        ).getErc20Module();
        address contractOnSchain = ILockAndDataERCOnSchain(lockAndDataERC20)
            .getERC20OnSchain("Mainnet", contractOnMainnet);
        require(
            IERC20(contractOnSchain).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Not allowed ERC20 Token"
        );
        require(
            IERC20(contractOnSchain).transferFrom(
                msg.sender,
                lockAndDataERC20,
                amount
            ),
            "Could not transfer ERC20 Token"
        );
        require(LockAndDataForSchain(getLockAndDataAddress()).reduceExit(msg.sender), "Does not allow to exit");
        bytes memory data = ERC20ModuleForSchain(erc20Module).receiveERC20(
            "Mainnet",
            contractOnMainnet,
            to,
            amount);
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            "Mainnet",
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked("Mainnet"))),
            0,
            address(0),
            data
        );
    }

    function transferToSchainERC20(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 amount
    )
        external
    {
        address lockAndDataERC20 = LockAndDataForSchain(getLockAndDataAddress()).getLockAndDataErc20();
        address erc20Module = LockAndDataForSchain(getLockAndDataAddress()).getErc20Module();
        address contractOnSchain = ILockAndDataERCOnSchain(lockAndDataERC20)
            .getERC20OnSchain(schainID, contractOnMainnet);
        require(
            IERC20(contractOnSchain).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Not allowed ERC20 Token"
        );
        require(
            IERC20(contractOnSchain).transferFrom(
                msg.sender,
                lockAndDataERC20,
                amount
            ),
            "Could not transfer ERC20 Token"
        );
        bytes memory data = ERC20ModuleForSchain(erc20Module).receiveERC20(
            schainID,
            contractOnMainnet,
            to,
            amount);
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            schainID,
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked("Mainnet"))),
            0,
            address(0),
            data
        );
    }

    function exitToMainERC721(address contractOnMainnet, address to, uint256 tokenId) external {
        address lockAndDataERC721 = LockAndDataForSchain(getLockAndDataAddress()).getLockAndDataErc721();
        address erc721Module = LockAndDataForSchain(getLockAndDataAddress()).getErc721Module();
        address contractOnSchain = ILockAndDataERCOnSchain(lockAndDataERC721)
            .getERC721OnSchain("Mainnet", contractOnMainnet);
        require(IERC721(contractOnSchain).ownerOf(tokenId) == address(this), "Not allowed ERC721 Token");
        IERC721(contractOnSchain).transferFrom(address(this), lockAndDataERC721, tokenId);
        require(IERC721(contractOnSchain).ownerOf(tokenId) == lockAndDataERC721, "Did not transfer ERC721 token");
        require(LockAndDataForSchain(getLockAndDataAddress()).reduceExit(msg.sender), "Does not allow to exit");
        bytes memory data = ERC721ModuleForSchain(erc721Module).receiveERC721(
            "Mainnet",
            contractOnMainnet,
            to,
            tokenId);
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            "Mainnet",
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked("Mainnet"))),
            0,
            address(0),
            data
        );
    }

    function transferToSchainERC721(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 tokenId
    ) 
        external
    {
        address lockAndDataERC721 = LockAndDataForSchain(getLockAndDataAddress()).getLockAndDataErc721();
        address erc721Module = LockAndDataForSchain(getLockAndDataAddress()).getErc721Module();
        address contractOnSchain = ILockAndDataERCOnSchain(lockAndDataERC721)
            .getERC721OnSchain(schainID, contractOnMainnet);
        require(IERC721(contractOnSchain).ownerOf(tokenId) == address(this), "Not allowed ERC721 Token");
        IERC721(contractOnSchain).transferFrom(address(this), lockAndDataERC721, tokenId);
        require(IERC721(contractOnSchain).ownerOf(tokenId) == lockAndDataERC721, "Did not transfer ERC721 token");
        bytes memory data = ERC721ModuleForSchain(erc721Module).receiveERC721(
            schainID,
            contractOnMainnet,
            to,
            tokenId);
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            schainID,
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked("Mainnet"))),
            0,
            address(0),
            data
        );
    }

    /**
     * @dev Allows MessageProxy to post operational message from mainnet
     * or SKALE chains.
     * 
     * Emits an {Error} event upon failure.
     *
     * Requirements:
     * 
     * - MessageProxy must be the sender.
     * - `fromSchainID` must exist in TokenManager addresses.
     */
    function postMessage(
        address sender,
        string calldata fromSchainID,
        address to,
        uint256 amount,
        bytes calldata data
    )
        external
    {
        require(data.length != 0, "Invalid data");
        require(msg.sender == getProxyForSchainAddress(), "Not a sender");
        bytes32 schainHash = keccak256(abi.encodePacked(fromSchainID));
        require(
            schainHash != keccak256(abi.encodePacked(getChainID())) && 
            sender == LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(schainHash),
            "Receiver chain is incorrect"
        );
        Messages.MessageType operation = Messages.getMessageType(data);
        if (operation == Messages.MessageType.TRANSFER_ETH) {
            require(to != address(0), "Incorrect receiver");
            require(LockAndDataForSchain(getLockAndDataAddress()).sendEth(to, amount), "Not Sent");
        } else if (operation == Messages.MessageType.TRANSFER_ERC20_AND_TOKEN_INFO) {
            address erc20Module = LockAndDataForSchain(
                getLockAndDataAddress()
            ).getErc20Module();
            require(ERC20ModuleForSchain(erc20Module).sendERC20(fromSchainID, data), "Failed to send ERC20");
            address receiver = ERC20ModuleForSchain(erc20Module).getReceiver(data);
            require(LockAndDataForSchain(getLockAndDataAddress()).sendEth(receiver, amount), "Not Sent");
        } else if (operation == Messages.MessageType.TRANSFER_ERC721) {
            address erc721Module = LockAndDataForSchain(
                getLockAndDataAddress()
            ).getErc721Module();
            require(ERC721ModuleForSchain(erc721Module).sendERC721(fromSchainID, data), "Failed to send ERC721");
            address receiver = ERC721ModuleForSchain(erc721Module).getReceiver(data);
            require(LockAndDataForSchain(getLockAndDataAddress()).sendEth(receiver, amount), "Not Sent");
        } else {
            revert("MessageType is unknown");
        }
    }

    /**
     * @dev Performs an exit (post outgoing message) to Mainnet.
     */
    function exitToMain(address to, uint256 amount) public {
        bytes memory empty = "";
        exitToMain(to, amount, empty);
    }

    /**
     * @dev Performs an exit (post outgoing message) to Mainnet.
     */
    function exitToMain(address to, uint256 amount, bytes memory data) public receivedEth(amount) {
        require(to != address(0), "Incorrect contractThere address");
        require(LockAndDataForSchain(getLockAndDataAddress()).reduceExit(msg.sender), "Does not allow to exit");
        bytes memory newData;
        newData = abi.encodePacked(bytes1(uint8(1)), data);
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            "Mainnet",
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked("Mainnet"))),
            amount,
            to,
            newData
        );
    }

    function transferToSchain(string memory schainID, address to, uint256 amount) public {
        bytes memory data = "";
        transferToSchain(
            schainID,
            to,
            amount,
            data);
    }

    function transferToSchain(
        string memory schainID,
        address to,
        uint256 amount,
        bytes memory data
    )
        public
        rightTransaction(schainID)
        receivedEth(amount)
    {
        require(to != address(0), "Incorrect contractThere address");
        IMessageProxy(getProxyForSchainAddress()).postOutgoingMessage(
            schainID,
            LockAndDataForSchain(getLockAndDataAddress()).tokenManagerAddresses(keccak256(abi.encodePacked(schainID))),
            amount,
            to,
            data
        );
    }

    /**
     * @dev Adds ETH cost for `msg.sender` exit transaction.
     */
    function addEthCost(uint256 amount) public {
        addEthCost(msg.sender, amount);
    }

    /**
     * @dev Adds ETH cost for user's exit transaction.
     */
    function addEthCost(address , uint256 amount) public receivedEth(amount) {
        revert("Temporarily unimplemented");
    }

    /**
     * @dev Returns chain ID.
     */
    function getChainID() public view returns ( string memory cID ) {
        if ((keccak256(abi.encodePacked(_chainID))) == (keccak256(abi.encodePacked(""))) ) {
            return SkaleFeatures(getSkaleFeaturesAddress())
                .getConfigVariableString("skaleConfig.sChain.schainName");
        }
        return _chainID;
    }

    /**
     * @dev Returns MessageProxy address.
     */
    function getProxyForSchainAddress() public view returns ( address ow ) {
        address proxyForSchainAddress = LockAndDataForSchain(
            getLockAndDataAddress()
        ).getMessageProxy();
        if (proxyForSchainAddress != address(0) )
            return proxyForSchainAddress;
        return SkaleFeatures(getSkaleFeaturesAddress()).getConfigVariableAddress(
            "skaleConfig.contractSettings.IMA.MessageProxy"
        );
    }
}
