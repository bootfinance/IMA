// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   DepositBox.sol - SKALE Interchain Messaging Agent
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

import "./interfaces/IMessageProxy.sol";
import "./interfaces/IERC20ModuleForMainnet.sol";
import "./interfaces/IERC721ModuleForMainnet.sol";

import "./PermissionsForMainnet.sol";
import "./Messages.sol";


interface ILockAndDataDB {
    function setContract(string calldata contractName, address newContract) external;
    function tokenManagerAddresses(bytes32 schainHash) external returns (address);
    function sendEth(address to, uint256 amount) external returns (bool);
    function approveTransfer(address to, uint256 amount) external;
    function addSchain(string calldata schainID, address tokenManagerAddress) external;
    function receiveEth(address from) external payable;
}

// This contract runs on the main net and accepts deposits


contract DepositBox is PermissionsForMainnet {

    uint256 public constant GAS_CONSUMPTION = 2000000000000000;

    event MoneyReceivedMessage(
        address sender,
        string fromSchainID,
        address to,
        uint256 amount,
        bytes data
    );

    event Error(
        address to,
        uint256 amount,
        string message
    );

    modifier rightTransaction(string memory schainID) {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = ILockAndDataDB(lockAndDataAddress_).tokenManagerAddresses(schainHash);
        require(schainHash != keccak256(abi.encodePacked("Mainnet")), "SKALE chain name is incorrect");
        require(tokenManagerAddress != address(0), "Unconnected chain");
        _;
    }

    modifier requireGasPayment() {
        require(msg.value >= GAS_CONSUMPTION, "Gas was not paid");
        _;
        ILockAndDataDB(lockAndDataAddress_).receiveEth.value(msg.value)(msg.sender);
    }

    fallback() external payable {
        revert("Not allowed. in DepositBox");
    }

    function depositWithoutData(string calldata schainID, address to) external payable {
        deposit(schainID, to);
    }

    function depositERC20(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 amount
    )
        external
        payable
        rightTransaction(schainID)
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = ILockAndDataDB(lockAndDataAddress_).tokenManagerAddresses(schainHash);
        address lockAndDataERC20 = IContractManager(lockAndDataAddress_).getContract(
            "LockAndDataERC20"
        );
        address erc20Module = IContractManager(lockAndDataAddress_).getContract(
            "ERC20Module"
        );
        address proxyAddress = IContractManager(lockAndDataAddress_).getContract(
            "MessageProxy"
        );
        require(
            IERC20(contractOnMainnet).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Not allowed ERC20 Token"
        );
        require(
            IERC20(contractOnMainnet).transferFrom(
                msg.sender,
                lockAndDataERC20,
                amount
            ),
            "Could not transfer ERC20 Token"
        );
        bytes memory data = IERC20ModuleForMainnet(erc20Module).receiveERC20(
            schainID,
            contractOnMainnet,
            to,
            amount);
        IMessageProxy(proxyAddress).postOutgoingMessage(
            schainID,
            tokenManagerAddress,
            msg.value,
            address(0),
            data
        );
        if (msg.value > 0) {
            ILockAndDataDB(lockAndDataAddress_).receiveEth.value(msg.value)(msg.sender);
        }
    }

    function depositERC721(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 tokenId
    )
        external
        payable
        rightTransaction(schainID)
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address lockAndDataERC721 = IContractManager(lockAndDataAddress_).getContract(
            "LockAndDataERC721"
        );
        address erc721Module = IContractManager(lockAndDataAddress_).getContract(
            "ERC721Module"
        );
        address proxyAddress = IContractManager(lockAndDataAddress_).getContract(
            "MessageProxy"
        );
        require(IERC721(contractOnMainnet).ownerOf(tokenId) == address(this), "Not allowed ERC721 Token");
        IERC721(contractOnMainnet).transferFrom(address(this), lockAndDataERC721, tokenId);
        require(IERC721(contractOnMainnet).ownerOf(tokenId) == lockAndDataERC721, "Did not transfer ERC721 token");
        bytes memory data =IERC721ModuleForMainnet(erc721Module).receiveERC721(
            schainID,
            contractOnMainnet,
            to,
            tokenId);
        IMessageProxy(proxyAddress).postOutgoingMessage(
            schainID,
            ILockAndDataDB(lockAndDataAddress_).tokenManagerAddresses(schainHash),
            msg.value,
            address(0),
            data
        );
        if (msg.value > 0) {
            ILockAndDataDB(lockAndDataAddress_).receiveEth.value(msg.value)(msg.sender);
        }
    }

    function postMessage(
        address sender,
        string calldata fromSchainID,
        address payable to,
        uint256 amount,
        bytes calldata data
    )
        external
        allow("MessageProxy")
    {
        require(data.length != 0, "Invalid data");
        bytes32 schainHash = keccak256(abi.encodePacked(fromSchainID));
        require(
            schainHash != keccak256(abi.encodePacked("Mainnet")) &&
            sender == ILockAndDataDB(lockAndDataAddress_).tokenManagerAddresses(schainHash),
            "Receiver chain is incorrect"
        );
        require(
            amount <= address(lockAndDataAddress_).balance ||
            amount >= GAS_CONSUMPTION,
            "Not enough money to finish this transaction"
        );
        require(
            ILockAndDataDB(lockAndDataAddress_).sendEth(getOwner(), GAS_CONSUMPTION),
            "Could not send money to owner"
        );
        _executePerOperation(to, amount, data);
    }

    /// Create a new deposit box
    function initialize(address newLockAndDataAddress) public override initializer {
        PermissionsForMainnet.initialize(newLockAndDataAddress);
    }

    function deposit(string memory schainID, address to) public payable {
        bytes memory empty = "";
        deposit(schainID, to, empty);
    }

    function deposit(string memory schainID, address to, bytes memory data)
        public
        payable
        rightTransaction(schainID)
        requireGasPayment
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = ILockAndDataDB(lockAndDataAddress_).tokenManagerAddresses(schainHash);
        address proxyAddress = IContractManager(lockAndDataAddress_).getContract(
            "MessageProxy"
        );
        bytes memory newData;
        newData = abi.encodePacked(bytes1(uint8(1)), data);
        IMessageProxy(proxyAddress).postOutgoingMessage(
            schainID,
            tokenManagerAddress,
            msg.value,
            to,
            newData
        );
    }

    function _executePerOperation(
        address payable to,
        uint256 amount,
        bytes calldata data    
    )
        internal
    {
        Messages.MessageType operation = Messages.getMessageType(data);
        if (operation == Messages.MessageType.TRANSFER_ETH) {
            if (amount > GAS_CONSUMPTION) {
                ILockAndDataDB(lockAndDataAddress_).approveTransfer(
                    to,
                    amount - GAS_CONSUMPTION
                );
            }
        } else if (operation == Messages.MessageType.TRANSFER_ERC20) {
            address erc20Module = IContractManager(lockAndDataAddress_).getContract(
                "ERC20Module"
            );
            require(IERC20ModuleForMainnet(erc20Module).sendERC20(data), "Sending of ERC20 was failed");
            address receiver = IERC20ModuleForMainnet(erc20Module).getReceiver(data);
            if (amount > GAS_CONSUMPTION) {
                ILockAndDataDB(lockAndDataAddress_).approveTransfer(
                    receiver,
                    amount - GAS_CONSUMPTION
                );
            }
        } else if (operation == Messages.MessageType.TRANSFER_ERC721) {
            address erc721Module = IContractManager(lockAndDataAddress_).getContract(
                "ERC721Module"
            );
            require(IERC721ModuleForMainnet(erc721Module).sendERC721(data), "Sending of ERC721 was failed");
            address receiver = IERC721ModuleForMainnet(erc721Module).getReceiver(data);
            if (amount > GAS_CONSUMPTION) {
                ILockAndDataDB(lockAndDataAddress_).approveTransfer(
                    receiver,
                    amount - GAS_CONSUMPTION
                );
            }
        } else {
            revert("MessageType is unknown");
        }
    }
}