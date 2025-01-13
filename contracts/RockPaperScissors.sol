// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {
    enum Move { Rock, Paper, Scissors }
    enum GameState { WaitingForPlayers, InProgress, Finished }

    address public admin;
    IERC20 public usdtToken;

    struct Game {
        address player1;
        address player2;
        uint256 player1Stake;
        uint256 player2Stake;
        Move player1Move;
        Move player2Move;
        GameState state;
        uint256 panelWeight; // Weight of the game panel (10, 50, 100, 1000)
    }

    Game[] public games;
    mapping(address => uint256) public winnings;

    // Game panel weights
    uint256[] public availableWeights = [10, 50, 100, 1000];

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyPlayer(uint256 gameId) {
        require(msg.sender == games[gameId].player1 || msg.sender == games[gameId].player2, "Only players can join the game");
        _;
    }

    modifier inState(uint256 gameId, GameState state) {
        require(games[gameId].state == state, "Invalid game state");
        _;
    }

    constructor(address _usdtToken) {
        admin = msg.sender;
        usdtToken = IERC20(_usdtToken);
    }

    // Function to create a game with a specific panel weight (10, 50, 100, or 1000)
    function createGame(uint256 panelWeight) external {
        require(isValidWeight(panelWeight), "Invalid weight selected");
        update();
        games.push(Game({
            player1: msg.sender,
            player2: address(0),
            player1Stake: panelWeight,
            player2Stake: 0,
            player1Move: Move(0),
            player2Move: Move(0),
            state: GameState.WaitingForPlayers,
            panelWeight: panelWeight
        }));

        // Player 1 stakes the specified panel weight
        usdtToken.transferFrom(msg.sender, address(this), panelWeight);
    }

    // Function to join an existing game with a specific panel weight
    function joinGame(uint256 gameId) external inState(gameId, GameState.WaitingForPlayers) {
        Game storage game = games[gameId];
        require(game.player2 == address(0), "Game already has two players");
        update();
        uint256 stakeAmount = game.panelWeight;
        game.player2 = msg.sender;
        game.player2Stake = stakeAmount;
        game.state = GameState.InProgress;

        // Player 2 stakes the same amount as Player 1
        usdtToken.transferFrom(msg.sender, address(this), stakeAmount);
    }

    // Function to make a move in the game (Rock, Paper, or Scissors)
    function makeMove(uint256 gameId, Move move) external onlyPlayer(gameId) inState(gameId, GameState.InProgress) {
        update();
        Game storage game = games[gameId];
        if (msg.sender == game.player1) {
            game.player1Move = move;
        } else {
            game.player2Move = move;
        }

        // Check if both players have made their move
        if (game.player1Move != Move(0) && game.player2Move != Move(0)) {
            endGame(gameId);
        }
    }

    // Internal function to determine the winner and distribute the winnings
    function endGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        address winner;

        // Determine winner based on the Rock-Paper-Scissors rules
        if (game.player1Move == game.player2Move) {
            winner = address(0); // Draw
        } else if (
            (game.player1Move == Move.Rock && game.player2Move == Move.Scissors) ||
            (game.player1Move == Move.Paper && game.player2Move == Move.Rock) ||
            (game.player1Move == Move.Scissors && game.player2Move == Move.Paper)
        ) {
            winner = game.player1;
        } else {
            winner = game.player2;
        }

        // Total prize pool is twice the stake of the game panel
        uint256 totalPrize = game.panelWeight * 2;

        if (winner != address(0)) {
            winnings[winner] += totalPrize; // Award the winner the total prize
        }

        game.state = GameState.Finished;
    }

    // Function for players to withdraw their winnings
    function withdrawWinnings() external {
        uint256 amount = winnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        winnings[msg.sender] = 0;
        usdtToken.transfer(msg.sender, amount);
    }

    // Helper function to validate if the weight is valid (10, 50, 100, or 1000)
    function isValidWeight(uint256 weight) internal view returns (bool) {
        for (uint i = 0; i < availableWeights.length; i++) {
            if (availableWeights[i] == weight) {
                return true;
            }
        }
        return false;
    }

    function update() internal {
        //game update status as archi
    } 
}
