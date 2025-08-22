// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RandomnessReceiverBase} from "randomness-solidity/src/RandomnessReceiverBase.sol";

/// @title Lottery Game Smart Contract
/// @notice A lottery game where players pick 3 numbers and try to match winning numbers
contract Lottery is RandomnessReceiverBase {
    // --- Game State ---
    enum GamePhase { WAITING, ACTIVE, DRAWING, FINISHED }
    
    struct LotteryGame {
        uint256 gameId;
        uint256[] winningNumbers;
        uint256 ticketPrice;
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
        uint256[] numbers;
        uint256 gameId;
        uint256 ticketId;
        bool claimed;
    }
    
    struct GameResult {
        address player;
        uint256 matches;
        uint256 prize;
        bool claimed;
    }
    
    // --- State Variables ---
    uint256 public currentGameId;
    mapping(uint256 => LotteryGame) public games;
    mapping(uint256 => PlayerTicket[]) public gameTickets;
    mapping(uint256 => GameResult[]) public gameResults;
    mapping(address => uint256[]) public playerGameHistory;
    
    // --- Prize Structure ---
    uint256 public constant JACKPOT_PERCENTAGE = 70; // 70% of prize pool
    uint256 public constant SECOND_PRIZE_PERCENTAGE = 20; // 20% of prize pool
    uint256 public constant THIRD_PRIZE_PERCENTAGE = 10; // 10% of prize pool
    
    // --- Randomness ---
    bytes32 public randomness;
    uint256 public requestId;
    uint256 public pendingGameId;
    
    // --- Events ---
    event GameCreated(uint256 indexed gameId, uint256 ticketPrice, uint256 maxTickets);
    event TicketPurchased(uint256 indexed gameId, address indexed player, uint256 ticketId, uint256[] numbers);
    event NumbersGenerated(uint256 indexed gameId, uint256[] winningNumbers);
    event GameFinished(uint256 indexed gameId, uint256 totalTickets, uint256 totalPrizePool);
    event PrizeClaimed(uint256 indexed gameId, address indexed player, uint256 prize, uint256 matches);
    
    // --- Modifiers ---
    modifier onlyActiveGame(uint256 gameId) {
        require(games[gameId].phase == GamePhase.ACTIVE, "Game not active");
        _;
    }
    
    modifier onlyDrawingPhase(uint256 gameId) {
        require(games[gameId].phase == GamePhase.DRAWING, "Not in drawing phase");
        _;
    }
    
    modifier onlyFinishedGame(uint256 gameId) {
        require(games[gameId].phase == GamePhase.FINISHED, "Game not finished");
        _;
    }
    
    // --- Constructor ---
    constructor(address randomnessSender, address owner)
        RandomnessReceiverBase(randomnessSender, owner)
    {}
    
    // --- Game Management ---
    function createGame(uint256 _ticketPrice, uint256 _maxTickets, uint256 _duration) external {
        currentGameId++;
        uint256 gameId = currentGameId;
        
        games[gameId] = LotteryGame({
            gameId: gameId,
            winningNumbers: new uint256[](0),
            ticketPrice: _ticketPrice,
            totalPrizePool: 0,
            maxTickets: _maxTickets,
            ticketsSold: 0,
            phase: GamePhase.WAITING,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            numbersGenerated: false
        });

         require(games[gameId].phase == GamePhase.WAITING, "Game not in waiting phase");
        games[gameId].phase = GamePhase.ACTIVE;
        
        emit GameCreated(gameId, _ticketPrice, _maxTickets);
    }
    
  
    
    function endGame(uint256 gameId) external  onlyActiveGame(gameId) {
        require(block.timestamp >= games[gameId].endTime, "Game time not elapsed");
        games[gameId].phase = GamePhase.DRAWING;
        
        // Request randomness for winning numbers
        pendingGameId = gameId;
        _requestRandomnessWithSubscription(200000); // Adjust gas limit as needed
    }
    
    // --- Ticket Management ---
    function purchaseTicket(uint256 gameId, uint256[3] calldata numbers) 
        external 
        payable 
        onlyActiveGame(gameId)
    {
        require(msg.value == games[gameId].ticketPrice, "Incorrect ticket price");
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
        
        emit TicketPurchased(gameId, msg.sender, ticketId, numbers);
    }
    
    function _validateNumbers(uint256[3] calldata numbers) internal pure returns (bool) {
        // Check range (1-100)
        for (uint256 i = 0; i < 3; i++) {
            if (numbers[i] < 1 || numbers[i] > 100) return false;
        }
        
        // Check for duplicates
        if (numbers[0] == numbers[1] || numbers[0] == numbers[2] || numbers[1] == numbers[2]) {
            return false;
        }
        
        return true;
    }
    
    // --- Randomness Callback ---
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestID == requestId, "Request ID mismatch");
        require(pendingGameId > 0, "No pending game");
        
        randomness = _randomness;
        uint256 gameId = pendingGameId;
        
        // Generate 3 unique winning numbers
        uint256[] memory winningNumbers = _generateWinningNumbers(_randomness);
        games[gameId].winningNumbers = winningNumbers;
        games[gameId].numbersGenerated = true;
        
        // Process all tickets and calculate results
        _processGameResults(gameId);
        
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
                // Generate number between 1-100
                randomNum = (uint256(keccak256(abi.encodePacked(_randomness, i, usedNumbers))) % 100 + 1);
                
                // Check if already used
                for (uint256 j = 0; j < i; j++) {
                    if (numbers[j] == randomNum) {
                        unique = false;
                        usedNumbers++;
                        break;
                    }
                }
            } while (!unique);
            
            numbers[i] = randomNum;
        }
        
        // Sort numbers
        _sortNumbers(numbers);
        return numbers;
    }
    
    function _sortNumbers(uint256[] memory numbers) internal pure {
        for (uint256 i = 0; i < numbers.length - 1; i++) {
            for (uint256 j = 0; j < numbers.length - i - 1; j++) {
                if (numbers[j] > numbers[j + 1]) {
                    uint256 temp = numbers[j];
                    numbers[j] = numbers[j + 1];
                    numbers[j + 1] = temp;
                }
            }
        }
    }
    
    function _processGameResults(uint256 gameId) internal {
        PlayerTicket[] storage tickets = gameTickets[gameId];
        uint256[] memory winningNumbers = games[gameId].winningNumbers;
        uint256 totalPrizePool = games[gameId].totalPrizePool;
        
        // Calculate prizes for each ticket
        for (uint256 i = 0; i < tickets.length; i++) {
            uint256 matches = _countMatches(tickets[i].numbers, winningNumbers);
            uint256 prize = _calculatePrize(matches, totalPrizePool, tickets.length);
            
            gameResults[gameId].push(GameResult({
                player: tickets[i].player,
                matches: matches,
                prize: prize,
                claimed: false
            }));
        }
    }
    
    function _countMatches(uint256[] memory playerNumbers, uint256[] memory winningNumbers) 
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
    
    function _calculatePrize(uint256 matches, uint256 totalPrizePool, uint256 totalTickets) 
        internal 
        pure 
        returns (uint256) 
    {
        if (matches == 0) return 0;
        
        uint256 prizePool;
        if (matches == 3) {
            prizePool = (totalPrizePool * JACKPOT_PERCENTAGE) / 100;
        } else if (matches == 2) {
            prizePool = (totalPrizePool * SECOND_PRIZE_PERCENTAGE) / 100;
        } else if (matches == 1) {
            prizePool = (totalPrizePool * THIRD_PRIZE_PERCENTAGE) / 100;
        }
        
        // Distribute among winners with same number of matches
        return prizePool / totalTickets; // Simplified distribution
    }
    
    // --- Prize Claiming ---
    function claimPrize(uint256 gameId, uint256 resultIndex) external onlyFinishedGame(gameId) {
        require(resultIndex < gameResults[gameId].length, "Invalid result index");
        GameResult storage result = gameResults[gameId][resultIndex];
        
        require(result.player == msg.sender, "Not your result");
        require(!result.claimed, "Already claimed");
        require(result.prize > 0, "No prize to claim");
        
        result.claimed = true;
        
        // Transfer prize
        (bool success, ) = msg.sender.call{value: result.prize}("");
        require(success, "Prize transfer failed");
        
        emit PrizeClaimed(gameId, msg.sender, result.prize, result.matches);
    }
    
    // --- View Functions ---
    function getGame(uint256 gameId) external view returns (LotteryGame memory) {
        return games[gameId];
    }
    
    function getGameTickets(uint256 gameId) external view returns (PlayerTicket[] memory) {
        return gameTickets[gameId];
    }
    
    function getGameResults(uint256 gameId) external view returns (GameResult[] memory) {
        return gameResults[gameId];
    }
    
    function getPlayerTickets(uint256 gameId, address player) external view returns (uint256[] memory) {
        PlayerTicket[] storage tickets = gameTickets[gameId];
        uint256[] memory playerTicketIds = new uint256[](tickets.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < tickets.length; i++) {
            if (tickets[i].player == player) {
                playerTicketIds[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = playerTicketIds[i];
        }
        
        return result;
    }
    
    function getPlayerGameHistory(address player) external view returns (uint256[] memory) {
        return playerGameHistory[player];
    }
    
    // --- Randomness Functions ---
    function generateWithDirectFunding(uint32 callbackGasLimit) public payable returns (uint256, uint256) {
        (uint256 requestID, uint256 requestPrice) = _requestRandomnessPayInNative(callbackGasLimit);
        requestId = requestID;
        return (requestID, requestPrice);
    }
    
    function generateWithSubscription(uint32 callbackGasLimit) public returns (uint256) {
        uint256 requestID = _requestRandomnessWithSubscription(callbackGasLimit);
        requestId = requestID;
        return requestID;
    }
    
    function cancelSubscription(address to) external onlyOwner {
        _cancelSubscription(to);
    }
    
    // --- Emergency Functions ---
    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
    
    function pauseGame(uint256 gameId) external onlyOwner {
        require(games[gameId].phase == GamePhase.ACTIVE, "Game not active");
        games[gameId].phase = GamePhase.WAITING;
    }
}
