// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {RandomnessReceiverBase} from "../../lib/randomness-solidity/src/RandomnessReceiverBase.sol";

/// @title Lottery Game Smart Contract
/// @author Randamu
/// @notice A lottery game that uses randomness for generating winning numbers
contract Lottery is RandomnessReceiverBase {
    // --- Game State ---
    enum GamePhase { WAITING, ACTIVE, DRAWING, FINISHED }
    
    struct LotteryGame {
        uint256 gameId;
        uint256[] winningNumbers;
        uint256 totalPrizePool;
        uint256 maxTickets;
        uint256 ticketsSold;
        GamePhase phase;
        uint256 startTime;
        uint256 endTime;
        bool numbersGenerated;
    }
    
    struct PlayerTicket {
        address player;
        uint256[3] numbers;
        uint256 gameId;
        uint256 ticketId;
        bool claimed;
    }
    
    // --- State Variables ---
    uint256 public currentGameId;
    mapping(uint256 => LotteryGame) public games;
    mapping(uint256 => PlayerTicket[]) public gameTickets;
    mapping(address => uint256[]) public playerGameHistory;
    
    // --- Constants ---
    uint256 public constant TICKET_PRICE = 1; // 1 wei
    uint256 public constant MAX_NUMBER = 100; // Numbers 1-100
    
    // --- Randomness ---
    bytes32 public randomness;
    uint256 public requestId;
    uint256 public pendingGameId;
    
    // --- Events ---
    event GameCreated(uint256 indexed gameId, uint256 maxTickets);
    event TicketPurchased(uint256 indexed gameId, address indexed player, uint256 ticketId, uint256[] numbers);
    event NumbersGenerated(uint256 indexed gameId, uint256[] winningNumbers);
    event GameFinished(uint256 indexed gameId, uint256 totalTickets, uint256 totalPrizePool);
    event PrizeClaimed(uint256 indexed gameId, address indexed player, uint256 prize, uint256 matches);
    
    // --- Modifiers ---
    modifier onlyActiveGame(uint256 gameId) {
        require(games[gameId].phase == GamePhase.ACTIVE, "Game not active");
        _;
    }
    
    modifier onlyGameOwner() {
        require(msg.sender == owner(), "Not owner");
        _;
    }
    
    // --- Constructor ---
    constructor(address randomnessSender, address owner) RandomnessReceiverBase(randomnessSender, owner) {}
    
    // --- Game Management ---
    function createGame(uint256 _maxTickets, uint256 _duration) external onlyGameOwner {
        currentGameId++;
        uint256 gameId = currentGameId;
        
        games[gameId] = LotteryGame({
            gameId: gameId,
            winningNumbers: new uint256[](0),
            totalPrizePool: 0,
            maxTickets: _maxTickets,
            ticketsSold: 0,
            phase: GamePhase.ACTIVE, // Start immediately
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            numbersGenerated: false
        });
        
        emit GameCreated(gameId, _maxTickets);
    }
    
    function endGame(uint256 gameId) external onlyGameOwner onlyActiveGame(gameId) {
        require(block.timestamp >= games[gameId].endTime, "Game time not elapsed");
        games[gameId].phase = GamePhase.DRAWING;
        
        // Request randomness for winning numbers using subscription
        pendingGameId = gameId;
        uint256 requestID = _requestRandomnessWithSubscription(200000);
        requestId = requestID;
    }
    
    // --- Ticket Management ---
    function purchaseTicket(uint256 gameId, uint256[3] calldata numbers) 
        external 
        payable 
        onlyActiveGame(gameId)
    {
        require(msg.value == TICKET_PRICE, "Ticket price must be 1 wei");
        require(games[gameId].ticketsSold < games[gameId].maxTickets, "Game sold out");
        require(_validateNumbers(numbers), "Invalid numbers");
        
        // Create ticket
        uint256 ticketId = gameTickets[gameId].length;
        gameTickets[gameId].push(PlayerTicket({
            player: msg.sender,
            numbers: numbers,
            gameId: gameId,
            ticketId: ticketId,
            claimed: false
        }));
        
        // Update game state
        games[gameId].ticketsSold++;
        games[gameId].totalPrizePool += msg.value;
        
        // Update player history
        playerGameHistory[msg.sender].push(gameId);
        
        uint256[] memory numbersArray = new uint256[](3);
        numbersArray[0] = numbers[0];
        numbersArray[1] = numbers[1];
        numbersArray[2] = numbers[2];
        emit TicketPurchased(gameId, msg.sender, ticketId, numbersArray);
    }
    
    function _validateNumbers(uint256[3] calldata numbers) internal pure returns (bool) {
        // Check range (1-10 for simplicity)
        for (uint256 i = 0; i < 3; i++) {
            if (numbers[i] < 1 || numbers[i] > MAX_NUMBER) return false;
        }
        
        // Check for duplicates
        if (numbers[0] == numbers[1] || numbers[0] == numbers[2] || numbers[1] == numbers[2]) {
            return false;
        }
        
        return true;
    }
    
    // --- Randomness Callback ---
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        require(pendingGameId > 0, "No pending game");
        
        randomness = _randomness;
        uint256 gameId = pendingGameId;
        
        // Generate 3 unique winning numbers using the actual randomness
        uint256[] memory winningNumbers = _generateWinningNumbers(_randomness);
        games[gameId].winningNumbers = winningNumbers;
        games[gameId].numbersGenerated = true;
        
        // Mark game as finished
        games[gameId].phase = GamePhase.FINISHED;
        
        emit NumbersGenerated(gameId, winningNumbers);
        emit GameFinished(gameId, games[gameId].ticketsSold, games[gameId].totalPrizePool);
        
        // Reset pending game
        pendingGameId = 0;
    }
    
    function _generateWinningNumbers(bytes32 _randomness) internal pure returns (uint256[] memory) {
        uint256[] memory numbers = new uint256[](3);
        uint256 usedNumbers = 0;
        
        for (uint256 i = 0; i < 3; i++) {
            uint256 randomNum;
            bool unique;
            
            do {
                unique = true;
                // Use the actual randomness from VRF system directly
                randomNum = (uint256(_randomness) + i + usedNumbers) % MAX_NUMBER + 1;
                
                // Check if number already used
                for (uint256 j = 0; j < usedNumbers; j++) {
                    if (numbers[j] == randomNum) {
                        unique = false;
                        break;
                    }
                }
            } while (!unique);
            
            numbers[i] = randomNum;
            usedNumbers++;
        }
        
        return numbers;
    }
    
    // --- Prize Distribution ---
    function claimPrize(uint256 gameId, uint256 ticketId) external {
        require(games[gameId].phase == GamePhase.FINISHED, "Game not finished");
        require(ticketId < gameTickets[gameId].length, "Invalid ticket");
        
        PlayerTicket storage ticket = gameTickets[gameId][ticketId];
        require(ticket.player == msg.sender, "Not your ticket");
        require(!ticket.claimed, "Already claimed");
        
        // Calculate matches
        uint256 matches = _calculateMatches(ticket.numbers, games[gameId].winningNumbers);
        
        // Calculate prize (simple: 1 wei per match)
        uint256 prize = matches * TICKET_PRICE;
        
        if (prize > 0) {
            ticket.claimed = true;
            payable(msg.sender).transfer(prize);
            emit PrizeClaimed(gameId, msg.sender, prize, matches);
        }
    }
    
    function _calculateMatches(uint256[3] memory playerNumbers, uint256[] memory winningNumbers) 
        internal 
        pure 
        returns (uint256) 
    {
        uint256 matches = 0;
        
        for (uint256 i = 0; i < playerNumbers.length; i++) {
            for (uint256 j = 0; j < winningNumbers.length; j++) {
                if (playerNumbers[i] == winningNumbers[j]) {
                    matches++;
                    break;
                }
            }
        }
        
        return matches;
    }
    
    // --- View Functions ---
    function getGame(uint256 gameId) external view returns (
        uint256 gameId_,
        uint256[] memory winningNumbers,
        uint256 totalPrizePool,
        uint256 maxTickets,
        uint256 ticketsSold,
        GamePhase phase,
        uint256 startTime,
        uint256 endTime,
        bool numbersGenerated
    ) {
        LotteryGame storage game = games[gameId];
        return (
            game.gameId,
            game.winningNumbers,
            game.totalPrizePool,
            game.maxTickets,
            game.ticketsSold,
            game.phase,
            game.startTime,
            game.endTime,
            game.numbersGenerated
        );
    }
    
    function getTicket(uint256 gameId, uint256 ticketId) external view returns (
        address player,
        uint256[3] memory numbers,
        uint256 gameId_,
        uint256 ticketId_,
        bool claimed
    ) {
        PlayerTicket storage ticket = gameTickets[gameId][ticketId];
        return (
            ticket.player,
            ticket.numbers,
            ticket.gameId,
            ticket.ticketId,
            ticket.claimed
        );
    }
    
    function getPlayerHistory(address player) external view returns (uint256[] memory) {
        return playerGameHistory[player];
    }
    
    // --- Emergency Functions ---
    function emergencyWithdraw() external onlyGameOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
