// SPDX-License-Identifier: AGPL-3.0-only

/**
 * @license
 * SKALE IMA
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/**
 * @file TokenManagerERC721.spec.ts
 * @copyright SKALE Labs 2019-Present
 */

import chaiAsPromised from "chai-as-promised";
import chai = require("chai");
import {
    ERC721OnChain,
    TokenManagerERC721,
    TokenManagerLinker,
    MessageProxyForSchainTester,
    MessagesTester,
} from "../typechain";

chai.should();
chai.use((chaiAsPromised as any));

import { deployTokenManagerERC721 } from "./utils/deploy/schain/tokenManagerERC721";
import { deployERC721OnChain } from "./utils/deploy/erc721OnChain";
import { deployMessageProxyForSchainTester } from "./utils/deploy/test/messageProxyForSchainTester";
import { deployTokenManagerLinker } from "./utils/deploy/schain/tokenManagerLinker";
import { deploySkaleFeaturesMock } from "./utils/deploy/test/skaleFeaturesMock";
import { deployMessages } from "./utils/deploy/messages";

import { ethers, web3 } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber } from "ethers";

import { assert, expect } from "chai";

describe("TokenManagerERC721", () => {
    let deployer: SignerWithAddress;
    let user: SignerWithAddress;
    let schainOwner: SignerWithAddress;

    const schainName = "V-chain";
    const tokenId = 1;
    let to: string;
    let token: ERC721OnChain;
    let tokenClone: ERC721OnChain;
    let tokenManagerERC721: TokenManagerERC721;
    let tokenManagerLinker: TokenManagerLinker;
    let messages: MessagesTester;
    let messageProxyForSchain: MessageProxyForSchainTester;

    before(async () => {
        [deployer, user, schainOwner] = await ethers.getSigners();
    });

    beforeEach(async () => {
        messageProxyForSchain = await deployMessageProxyForSchainTester(schainName);
        tokenManagerLinker = await deployTokenManagerLinker(messageProxyForSchain);
        messages = await deployMessages();
        const fakeDepositBox =  messages;

        const skaleFeatures = await deploySkaleFeaturesMock();
        await skaleFeatures.setSchainOwner(schainOwner.address);

        tokenManagerERC721 =
            await deployTokenManagerERC721(schainName, messageProxyForSchain.address, tokenManagerLinker, fakeDepositBox.address);
        await tokenManagerERC721.grantRole(await tokenManagerERC721.SKALE_FEATURES_SETTER_ROLE(), deployer.address);
        await tokenManagerERC721.setSkaleFeaturesAddress(skaleFeatures.address);


        tokenClone = await deployERC721OnChain("ELVIS", "ELV");
        token = await deployERC721OnChain("SKALE", "SKL");

        to = user.address;

    });

    it("should change depositBox address", async () => {
        const newDepositBox = user;
        expect(await tokenManagerERC721.depositBox()).to.equal(messages.address);
        await tokenManagerERC721.changeDepositBoxAddress(newDepositBox, {from: user})
          .should.be.eventually.rejectedWith("Sender is not an Schain owner");
        await tokenManagerERC721.changeDepositBoxAddress(newDepositBox, {from: schainOwner});
        expect(await tokenManagerERC721.depositBox()).to.equal(newDepositBox);
      });

    it("should successfully call exitToMainERC721", async () => {
        await tokenManagerERC721.connect(user).exitToMainERC721(token.address, to, tokenId)
            .should.be.eventually.rejectedWith("No token clone on schain");

        await tokenManagerERC721.connect(schainOwner).addERC721TokenByOwner(token.address, tokenClone.address);
        await tokenManagerERC721.connect(user).exitToMainERC721(token.address, to, tokenId)
            .should.be.eventually.rejectedWith("ERC721: approved query for nonexistent token");

        await tokenClone.connect(deployer).mint(user.address, tokenId);
        await tokenManagerERC721.connect(user).exitToMainERC721(token.address, to, tokenId)
            .should.be.eventually.rejectedWith("Not allowed ERC721 Token");

        await tokenClone.connect(user).approve(tokenManagerERC721.address, tokenId);
        await tokenManagerERC721.connect(user).exitToMainERC721(token.address, to, tokenId);

        const outgoingMessagesCounterMainnet = BigNumber.from(
            await messageProxyForSchain.getOutgoingMessagesCounter("Mainnet")
        );
        outgoingMessagesCounterMainnet.should.be.deep.equal(BigNumber.from(1));
    });

    it("should successfully call addERC721TokenByOwner", async () => {
        await tokenManagerERC721.connect(deployer).addERC721TokenByOwner(token.address, tokenClone.address)
            .should.be.eventually.rejectedWith("Sender is not an Schain owner");

        await tokenManagerERC721.connect(schainOwner).addERC721TokenByOwner(token.address, deployer.address)
            .should.be.eventually.rejectedWith("Given address is not a contract");

        await tokenManagerERC721.connect(schainOwner).addERC721TokenByOwner(token.address, tokenClone.address);
    });

    it("should successfully call transferToSchainERC721", async () => {

        const chainConnectorRole = await messageProxyForSchain.CHAIN_CONNECTOR_ROLE();
        await messageProxyForSchain.grantRole(chainConnectorRole, deployer.address);
        await messageProxyForSchain.connect(deployer).addConnectedChain(schainName);

        await tokenManagerERC721
            .connect(deployer)
            .transferToSchainERC721(schainName, token.address, to, tokenId)
            .should.be.eventually.rejectedWith("Incorrect Token Manager address");

        await tokenManagerERC721.addTokenManager(schainName, deployer.address);
        await tokenManagerERC721.connect(schainOwner).addERC721TokenByOwner(token.address, tokenClone.address);
        await tokenClone.connect(deployer).mint(deployer.address, tokenId);

        await tokenManagerERC721
            .connect(deployer)
            .transferToSchainERC721(schainName, token.address, to, tokenId)
            .should.be.eventually.rejectedWith("Not allowed ERC721 Token");

        await tokenClone.connect(deployer).approve(tokenManagerERC721.address, tokenId);

        // execution:
        await tokenManagerERC721
            .connect(deployer)
            .transferToSchainERC721(schainName, token.address, to, tokenId);
        // expectation:
        const outgoingMessagesCounter = BigNumber.from(
            await messageProxyForSchain.getOutgoingMessagesCounter(schainName)
        );
        outgoingMessagesCounter.should.be.deep.equal(BigNumber.from(1));
    });

    it("should transfer ERC721 token through `postMessage` function", async () => {
        //  preparation
        const fakeDepositBox =  messages;
        const chainName = "Mainnet";
        const data = await messages.encodeTransferErc721AndTokenInfoMessage(
            token.address,
            to,
            tokenId,
            {
                name: await token.name(),
                symbol: await token.symbol()
            }
        );

        await tokenManagerERC721.connect(schainOwner).enableAutomaticDeploy();
        await messageProxyForSchain.postMessage(tokenManagerERC721.address, chainName, fakeDepositBox.address, data);
        const addressERC721OnSchain = await tokenManagerERC721.clonesErc721(token.address);
        const erc721OnChain = await (await ethers.getContractFactory("ERC721OnChain")).attach(addressERC721OnSchain) as ERC721OnChain;
        expect((await erc721OnChain.functions.ownerOf(tokenId))[0]).to.be.equal(to);
    });

});
