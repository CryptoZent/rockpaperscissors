const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockPaperScissors", function () {
    let RockPaperScissors, contract, USDT, usdt, owner, player1, player2;

    beforeEach(async () => {
        [owner, player1, player2] = await ethers.getSigners();

        // Deploy a mock USDT token
        USDT = await ethers.getContractFactory("MockERC20");
        usdt = await USDT.deploy("USDT", "USDT", ethers.utils.parseEther("10000"));

        // Deploy the RockPaperScissors contract
        RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");
        contract = await RockPaperScissors.deploy(usdt.address);

        // Distribute tokens to players
        await usdt.transfer(player1.address, ethers.utils.parseEther("1000"));
        await usdt.transfer(player2.address, ethers.utils.parseEther("1000"));

        // Approve tokens for the contract
        await usdt.connect(player1).approve(contract.address, ethers.utils.parseEther("1000"));
        await usdt.connect(player2).approve(contract.address, ethers.utils.parseEther("1000"));
    });

    it("should allow a player to create a game", async () => {
        await contract.connect(player1).createGame(10);
        const game = await contract.games(0);
        expect(game.player1).to.equal(player1.address);
        expect(game.state).to.equal(0); // WaitingForPlayers
    });

    it("should allow a second player to join a game", async () => {
        await contract.connect(player1).createGame(10);
        await contract.connect(player2).joinGame(0);
        const game = await contract.games(0);
        expect(game.player2).to.equal(player2.address);
        expect(game.state).to.equal(1); // InProgress
    });

    it("should mark a game as NotPlayed if time exceeds", async () => {
        await contract.connect(player1).createGame(10);

        // Simulate time passing
        await ethers.provider.send("evm_increaseTime", [60]);
        await contract.update();

        const game = await contract.games(0);
        expect(game.state).to.equal(3); // NotPlayed
    });

    it("should determine the correct winner", async () => {
        await contract.connect(player1).createGame(10);
        await contract.connect(player2).joinGame(0);

        await contract.connect(player1).makeMove(0, 1); // Player1: Rock
        await contract.connect(player2).makeMove(0, 3); // Player2: Scissors

        const game = await contract.games(0);
        expect(game.state).to.equal(2); // Finished
        expect(await contract.winnings(player1.address)).to.equal(20);
    });

    it("should allow the winner to withdraw winnings", async () => {
        await contract.connect(player1).createGame(10);
        await contract.connect(player2).joinGame(0);

        await contract.connect(player1).makeMove(0, 1); // Player1: Rock
        await contract.connect(player2).makeMove(0, 3); // Player2: Scissors

        await contract.connect(player1).withdrawWinnings();
        expect(await usdt.balanceOf(player1.address)).to.equal(ethers.utils.parseEther("1010"));
    });
});
