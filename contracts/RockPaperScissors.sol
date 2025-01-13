// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {
    enum Move { None, Rock, Paper, Scissors }
    enum GameState { WaitingForPlayers, InProgress, Finished, ExceedTime }

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
        uint256 panelWeight;
        uint256 startTime; // Game start time
    }

    Game[] public games;
    mapping(address => uint256) public winnings;

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

    function createGame(uint256 panelWeight) external {
        require(isValidWeight(panelWeight), "Invalid weight selected");
        update();

        games.push(Game({
            player1: msg.sender,
            player2: address(0),
            player1Stake: panelWeight,
            player2Stake: 0,
            player1Move: Move.None,
            player2Move: Move.None,
            state: GameState.WaitingForPlayers,
            panelWeight: panelWeight,
            startTime: block.timestamp
        }));

        usdtToken.transferFrom(msg.sender, address(this), panelWeight);
    }

    function joinGame(uint256 gameId) external inState(gameId, GameState.WaitingForPlayers) {
        update();
        Game storage game = games[gameId];
        require(game.player2 == address(0), "Game already has two players");

        game.player2 = msg.sender;
        game.player2Stake = game.panelWeight;
        game.state = GameState.InProgress;
        game.startTime = block.timestamp; // Reset timer when both players join

        usdtToken.transferFrom(msg.sender, address(this), game.panelWeight);
    }

    function makeMove(uint256 gameId, Move move) external onlyPlayer(gameId) inState(gameId, GameState.InProgress) {
        update();
        Game storage game = games[gameId];

        if (msg.sender == game.player1) {
            game.player1Move = move;
        } else {
            game.player2Move = move;
        }

        if (game.player1Move != Move.None && game.player2Move != Move.None) {
            endGame(gameId);
        }
    }

    function update() public {
        for (uint256 i = 0; i < games.length; i++) {
            if (
                games[i].state == GameState.WaitingForPlayers ||
                games[i].state == GameState.InProgress
            ) {
                if (block.timestamp > games[i].startTime + 1 minutes) {
                    games[i].state = GameState.ExceedTime;
                }
            }
        }
    }

    function getActiveGames() external view returns (Game[] memory) {
        uint256 count;
        for (uint256 i = 0; i < games.length; i++) {
            if (
                games[i].state == GameState.WaitingForPlayers ||
                games[i].state == GameState.InProgress
            ) {
                count++;
            }
        }

        Game[] memory activeGames = new Game[](count);
        uint256 index;
        for (uint256 i = 0; i < games.length; i++) {
            if (
                games[i].state == GameState.WaitingForPlayers ||
                games[i].state == GameState.InProgress
            ) {
                activeGames[index++] = games[i];
            }
        }
        return activeGames;
    }

    function endGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        address winner;

        if (game.player1Move == game.player2Move) {
            winner = address(0);
        } else if (
            (game.player1Move == Move.Rock && game.player2Move == Move.Scissors) ||
            (game.player1Move == Move.Paper && game.player2Move == Move.Rock) ||
            (game.player1Move == Move.Scissors && game.player2Move == Move.Paper)
        ) {
            winner = game.player1;
        } else {
            winner = game.player2;
        }

        uint256 totalPrize = game.panelWeight * 2;

        if (winner != address(0)) {
            winnings[winner] += totalPrize;
        }

        game.state = GameState.Finished;
    }

    function withdrawWinnings() external {
        uint256 amount = winnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        winnings[msg.sender] = 0;
        usdtToken.transfer(msg.sender, amount);
    }

    function isValidWeight(uint256 weight) internal view returns (bool) {
        for (uint256 i = 0; i < availableWeights.length; i++) {
            if (availableWeights[i] == weight) {
                return true;
            }
        }
        return false;
    }
}
