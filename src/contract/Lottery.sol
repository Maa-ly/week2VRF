// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {RandomnessReceiverBase} from "../../lib/randomness-solidity/src/RandomnessReceiverBase.sol";
import {AbstractBlocklockReceiver} from "blocklock-solidity/src/AbstractBlocklockReceiver.sol";
import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";
import {BLS} from "blocklock-solidity/src/libraries/BLS.sol";

/// @title Lottery Game Smart Contract with Blocklock Integration
/// @author Randamu
/// @notice A lottery game that uses randomness and conditional encryption for secure reveals
contract Lottery is RandomnessReceiverBase, AbstractBlocklockReceiver {
    // --- Game State ---
    enum GamePhase { WAITING, ACTIVE, DRAWING, SEALED, FINISHED }
    
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
    
    // --- Blocklock Integration ---
    
    struct SealedGame {
        uint256 gameId;
        uint256 requestId;
        TypesLib.Ciphertext encryptedWinningNumbers;
        bytes condition;
        uint256 unlockTime;
        bool isRevealed;
    }
    
    mapping(uint256 => SealedGame) public sealedGames;
    mapping(uint256 => uint256) public gameIdToSealId;
    uint256 public nextSealId = 1;
    
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
    event GameSealed(uint256 indexed gameId, uint256 indexed sealId, uint256 unlockTime);
    event GameRevealed(uint256 indexed gameId, uint256[] winningNumbers);
    
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
    constructor(
        address randomnessSender, 
        address owner,
        address blocklockSender
    ) RandomnessReceiverBase(randomnessSender, owner) AbstractBlocklockReceiver(blocklockSender) {}
    
    // --- Override Conflicting Functions ---
    
    /// @notice Override to resolve conflict between base contracts
    function _subscribe() internal override returns (uint256 subId) {
        return AbstractBlocklockReceiver._subscribe();
    }
    
    /// @notice Override to resolve conflict between base contracts
    function _cancelSubscription(address to) internal override {
        AbstractBlocklockReceiver._cancelSubscription(to);
    }
    
    /// @notice Override to resolve conflict between base contracts
    function setSubId(uint256 subId) external override onlyOwner {
        AbstractBlocklockReceiver.setSubId(subId);
    }
    
    /// @notice Override to resolve conflict between base contracts
    function updateSubscription(address[] calldata consumers) external override onlyOwner {
        AbstractBlocklockReceiver.updateSubscription(consumers);
    }
    
    /// @notice Override to resolve conflict between base contracts
    function createSubscriptionAndFundNative() external payable override onlyOwner {
        AbstractBlocklockReceiver.createSubscriptionAndFundNative{value: msg.value}();
    }
    
    /// @notice Override to resolve conflict between base contracts
    function topUpSubscriptionNative() external payable override {
        AbstractBlocklockReceiver.topUpSubscriptionNative{value: msg.value}();
    }
    
    /// @notice Override to resolve conflict between base contracts
    function getBalance() public view override returns (uint256) {
        return AbstractBlocklockReceiver.getBalance();
    }
    
    /// @notice Override to resolve conflict between base contracts
    function isInFlight(uint256 __requestId) public view override returns (bool) {
        return AbstractBlocklockReceiver.isInFlight(__requestId);
    }
    
    /// @notice Override to resolve conflict between base contracts
    function pendingRequestExists(uint256 subId) public view override returns (bool) {
        return AbstractBlocklockReceiver.pendingRequestExists(subId);
    }
    
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
    
    // --- Modified Randomness Callback with Blocklock ---
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        require(pendingGameId > 0, "No pending game");
        
        randomness = _randomness;
        uint256 gameId = pendingGameId;
        
        // Generate winning numbers but don't reveal them yet
        uint256[] memory winningNumbers = _generateWinningNumbers(_randomness);
        
        // Seal the winning numbers with Blocklock instead of revealing immediately
        _sealWinningNumbers(gameId, winningNumbers);
        
        // Game stays in SEALED phase until Blocklock reveals
        games[gameId].phase = GamePhase.SEALED;
        
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
    
    // --- Blocklock Integration Functions ---
    
    /// @notice Seal winning numbers with time-based reveal
    function _sealWinningNumbers(uint256 gameId, uint256[] memory numbers) internal {
        uint256 sealId = nextSealId++;
        
        // Create time-based condition (reveal after 1 hour for suspense)
        uint256 unlockTime = block.timestamp + 1 hours;
        bytes memory condition = abi.encode("TIME", unlockTime);
        
        // Encrypt the winning numbers
        TypesLib.Ciphertext memory ciphertext = _createEncryptedNumbers(numbers);
        
        // Request blocklock using inherited function
        (uint256 _requestId, uint256 requestPrice) = _requestBlocklockPayInNative(200000, condition, ciphertext);
        
        // Store sealed game
        sealedGames[sealId] = SealedGame({
            gameId: gameId,
            requestId: requestId,
            encryptedWinningNumbers: ciphertext,
            condition: condition,
            unlockTime: unlockTime,
            isRevealed: false
        });
        
        gameIdToSealId[gameId] = sealId;
        
        emit GameSealed(gameId, sealId, unlockTime);
    }
    
    /// @notice Create encrypted payload for winning numbers
    function _createEncryptedNumbers(uint256[] memory numbers) internal pure returns (TypesLib.Ciphertext memory) {
        // This is a simplified implementation - in practice, you'd use blocklock-js
        // to properly encrypt the data before calling this function
        bytes memory encodedNumbers = abi.encode(numbers);
        
        return TypesLib.Ciphertext({
            u: BLS.PointG2({ x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)] }), // Placeholder - would be set by blocklock-js
            v: encodedNumbers,
            w: encodedNumbers
        });
    }
    
    /// @notice External wrapper for decryption (for try-catch)
    function _decryptWinningNumbers(TypesLib.Ciphertext calldata ciphertext, bytes calldata decryptionKey) 
        external view returns (uint256[] memory) {
        bytes memory decrypted = _decrypt(ciphertext, decryptionKey);
        return abi.decode(decrypted, (uint256[]));
    }
    
    /// @notice Blocklock callback when conditions are met
    function _onBlocklockReceived(uint256 _requestId, bytes calldata decryptionKey) internal override {
        // Find the sealed game for this request
        uint256 sealId = _findSealByRequestId(_requestId);
        
        if (sealId == 0) {
            return; // Request ID not found
        }
        
        SealedGame storage seal = sealedGames[sealId];
        
        try this._decryptWinningNumbers(seal.encryptedWinningNumbers, decryptionKey) returns (uint256[] memory numbers) {
            // Reveal the winning numbers
            _revealWinningNumbers(seal.gameId, numbers);
            
            // Mark seal as revealed
            seal.isRevealed = true;
            
        } catch {
            // Decryption failed - could emit event or handle error
        }
    }
    
    /// @notice Find sealed game by request ID
    function _findSealByRequestId(uint256 _requestId) internal view returns (uint256) {
        for (uint256 i = 1; i < nextSealId; i++) {
            if (sealedGames[i].requestId == requestId) {
                return i;
            }
        }
        return 0;
    }
    
    /// @notice Reveal winning numbers and finish game
    function _revealWinningNumbers(uint256 gameId, uint256[] memory numbers) internal {
        LotteryGame storage game = games[gameId];
        
        // Set winning numbers
        game.winningNumbers = numbers;
        game.numbersGenerated = true;
        
        // Mark game as finished
        game.phase = GamePhase.FINISHED;
        
        emit NumbersGenerated(gameId, numbers);
        emit GameFinished(gameId, game.ticketsSold, game.totalPrizePool);
        emit GameRevealed(gameId, numbers);
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
    
    // --- Enhanced View Functions for Blocklock ---
    
    /// @notice Check if a game is ready to be revealed
    function isGameReadyToReveal(uint256 gameId) external view returns (bool) {
        uint256 sealId = gameIdToSealId[gameId];
        if (sealId == 0) return false;
        
        SealedGame storage seal = sealedGames[sealId];
        return block.timestamp >= seal.unlockTime;
    }
    
    /// @notice Get sealed game details
    function getSealedGame(uint256 gameId) external view returns (
        uint256 sealId,
        uint256 unlockTime,
        bool isRevealed
    ) {
        sealId = gameIdToSealId[gameId];
        if (sealId == 0) revert("Game not sealed");
        
        SealedGame storage seal = sealedGames[sealId];
        return (sealId, seal.unlockTime, seal.isRevealed);
    }
    
    /// @notice Get all sealed games for a player
    function getPlayerSealedGames(address player) external view returns (uint256[] memory) {
        uint256[] memory playerGames = playerGameHistory[player];
        uint256[] memory sealedGameIds = new uint256[](playerGames.length);
        uint256 sealedCount = 0;
        
        for (uint256 i = 0; i < playerGames.length; i++) {
            uint256 gameId = playerGames[i];
            if (gameIdToSealId[gameId] != 0) {
                sealedGameIds[sealedCount] = gameId;
                sealedCount++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](sealedCount);
        for (uint256 i = 0; i < sealedCount; i++) {
            result[i] = sealedGameIds[i];
        }
        
        return result;
    }
    
    // --- Emergency Functions ---
    function emergencyWithdraw() external onlyGameOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /// @notice Emergency function to manually reveal if blocklock fails
    function emergencyReveal(uint256 gameId, uint256[] memory numbers) external onlyGameOwner {
        require(gameIdToSealId[gameId] != 0, "Game not sealed");
        require(games[gameId].phase == GamePhase.SEALED, "Game not in sealed phase");
        
        SealedGame storage seal = sealedGames[gameIdToSealId[gameId]];
        require(!seal.isRevealed, "Already revealed");
        require(block.timestamp > seal.unlockTime + 24 hours, "Must wait 24 hours after unlock time");
        
        // Validate numbers
        require(numbers.length == 3, "Invalid number count");
        for (uint256 i = 0; i < 3; i++) {
            require(numbers[i] >= 1 && numbers[i] <= MAX_NUMBER, "Invalid number range");
        }
        
        // Reveal manually
        _revealWinningNumbers(gameId, numbers);
        seal.isRevealed = true;
    }
}
