// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MatchingPenniesPro {
    struct PennyGame {
        address initiator;
        address opponent;
        bytes32 hashedPick;
        uint8 opponentPick;
        uint256 wagerAmount;
        bool isRevealed;
        bool isConcluded;
        uint256 startTime;
    }

    mapping(uint256 => PennyGame) public games;
    uint256 public totalGames;
    mapping(address => uint256) public winnings;

    event GameInitialized(uint256 gameId, address initiator, uint256 wagerAmount);
    event OpponentJoined(uint256 gameId, address opponent);
    event GameFinalized(uint256 gameId, address victor);

    function startGame(bytes32 hashedSelection) external payable {
        require(msg.value == 0.05 ether, "Wager must be exactly 0.05 ETH");
        
        games[totalGames] = PennyGame(
            msg.sender, 
            address(0), 
            hashedSelection, 
            0, 
            msg.value, 
            false, 
            false, 
            block.timestamp
        );

        emit GameInitialized(totalGames, msg.sender, msg.value);
        totalGames++;
    }

    function enterGame(uint256 gameId, uint8 selection) external payable {
        require(gameId < totalGames, "Game does not exist");
        PennyGame storage game = games[gameId];
        require(game.opponent == address(0), "Game already occupied");
        require(msg.value == game.wagerAmount, "Incorrect wager amount");
        require(selection == 0 || selection == 1, "Invalid selection");

        game.opponent = msg.sender;
        game.opponentPick = selection;

        emit OpponentJoined(gameId, msg.sender);
    }

    function revealSelection(uint256 gameId, uint8 originalChoice, string memory salt) external {
        PennyGame storage game = games[gameId];
        require(msg.sender == game.initiator, "Only the initiator can reveal");
        require(!game.isRevealed, "Choice already revealed");
        require(game.opponent != address(0), "No opponent joined yet");
        require(keccak256(abi.encodePacked(originalChoice, salt)) == game.hashedPick, "Choice verification failed");

        game.isRevealed = true;
        game.isConcluded = true;

        address victor = (originalChoice == game.opponentPick) ? game.initiator : game.opponent;
        uint256 prize = (2 * game.wagerAmount) - (tx.gasprice * 21000); // Accounting for gas

        winnings[victor] += prize;
        
        emit GameFinalized(gameId, victor);
    }

    function claimWinnings() external {
        uint256 payout = winnings[msg.sender];
        require(payout > 0, "No funds to claim");
        
        winnings[msg.sender] = 0;
        payable(msg.sender).transfer(payout);
    }

    function requestRefund(uint256 gameId) external {
        PennyGame storage game = games[gameId];
        require(!game.isRevealed, "Refund unavailable after reveal");
        require(block.timestamp > (game.startTime + 2 hours), "Refund window not open");

        payable(game.initiator).transfer(game.wagerAmount);
        if (game.opponent != address(0)) {
            payable(game.opponent).transfer(game.wagerAmount);
        }
        game.isConcluded = true;
    }
}
