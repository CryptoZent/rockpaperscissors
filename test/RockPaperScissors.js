const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockPaperScissors", function () {
    let RockPaperScissors, contract, USDT, usdt, owner, player1, player2;

    beforeEach(async () => {
        [owner, player1, player2] = await ethers.getSigners();

        // Deploy a mock USDT token
        const USDT = await ethers.getContractFactory("MockERC20");
        usdt = await USDT.deploy("USDT", "USDT", ethers.parseUnits("10000", 18));

        // Deploy the RockPaperScissors contract
        RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");
        contract = await RockPaperScissors.deploy(usdt.target); // Use .target instead of .address in ethers v6

        // Distribute tokens to players
        await usdt.transfer(player1.address, ethers.parseUnits("1000", 18));
        await usdt.transfer(player2.address, ethers.parseUnits("1000", 18));

        // Approve tokens for the contract
        await usdt.connect(player1).approve(contract.target, ethers.parseUnits("1000", 18)); // Use .target
        await usdt.connect(player2).approve(contract.target, ethers.parseUnits("1000", 18));
    });

    it("should allow a player to create a game", async () => {
        await contract.connect(player1).createGame(10);
        const game = await contract.games(0);
        expect(game.player1).to.equal(player1.address);
        expect(game.state).to.equal(0); // WaitingForPlayers
    });
});
