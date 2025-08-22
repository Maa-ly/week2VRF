// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../Lottery.sol";
import {RandomnessSender} from "randomness-solidity/src/RandomnessSender.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    RandomnessSender public randomnessSender;
    
    address public owner = address(0x1);
    address public player1 = address(0x2);
    address public player2 = address(0x3);
    address public player3 = address(0x4);
    
    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant MAX_TICKETS = 100;
    uint256 public constant GAME_DURATION = 1 hours;
    
    event GameCreated(uint256 indexed gameId, uint256 ticketPrice, uint256 maxTickets);
    event TicketPurchased(uint256 indexed gameId, address indexed player, uint256 ticketId, uint256[] numbers);
    event NumbersGenerated(uint256 indexed gameId, uint256[] winningNumbers);
    event GameFinished(uint256 indexed gameId, uint256 totalTickets, uint256 totalPrizePool);
    event PrizeClaimed(uint256 indexed gameId, address indexed player, uint256 prize, uint256 matches);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy RandomnessSender (mock for testing)
        randomnessSender = new RandomnessSender();
        
        // Deploy Lottery contract
        lottery = new Lottery(address(randomnessSender), owner);
        
        vm.stopPrank();
        
        // Fund players
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
    }
    
    function test_Constructor() public {
        assertEq(lottery.owner(), owner);
        assertEq(lottery.currentGameId(), 0);
    }
    
    function test_CreateGame() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, false, false, true);
        emit GameCreated(1, TICKET_PRICE, MAX_TICKETS);
        
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        
        assertEq(lottery.currentGameId(), 1);
        
        // Check game state
        (uint256 gameId, , uint256 ticketPrice, , uint256 maxTickets, , , , , , ) = lottery.games(1);
        assertEq(gameId, 1);
        assertEq(ticketPrice, TICKET_PRICE);
        assertEq(maxTickets, MAX_TICKETS);
        
        vm.stopPrank();
    }
    
    function test_StartGame() public {
        vm.startPrank(owner);
        
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        
        // Check game phase
        (,,,,,, uint8 phase, , , ) = lottery.games(1);
        assertEq(uint256(phase), 1); // ACTIVE phase
        
        vm.stopPrank();
    }
    
    function test_PurchaseTicket() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        uint256[3] memory numbers = [7, 23, 45];
        
        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(1, player1, 0, numbers);
        
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers);
        
        // Check ticket was created
        (address ticketPlayer, , , , , ) = lottery.gameTickets(1, 0);
        assertEq(ticketPlayer, player1);
        
        // Check game state updated
        (,,,, uint256 totalPrizePool, uint256 ticketsSold, , , , ) = lottery.games(1);
        assertEq(totalPrizePool, TICKET_PRICE);
        assertEq(ticketsSold, 1);
        
        vm.stopPrank();
    }
    
    function test_PurchaseTicketInvalidNumbers() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        // Test invalid numbers (duplicates)
        uint256[3] memory duplicateNumbers = [7, 7, 45];
        vm.expectRevert("Invalid numbers");
        lottery.purchaseTicket{value: TICKET_PRICE}(1, duplicateNumbers);
        
        // Test invalid numbers (out of range)
        uint256[3] memory outOfRangeNumbers = [0, 23, 101];
        vm.expectRevert("Invalid numbers");
        lottery.purchaseTicket{value: TICKET_PRICE}(1, outOfRangeNumbers);
        
        vm.stopPrank();
    }
    
    function test_PurchaseTicketIncorrectValue() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        uint256[3] memory numbers = [7, 23, 45];
        
        // Test with wrong ticket price
        vm.expectRevert("Incorrect ticket price");
        lottery.purchaseTicket{value: 0.02 ether}(1, numbers);
        
        vm.stopPrank();
    }
    
    function test_PurchaseTicketGameNotActive() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        // Don't start the game
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        uint256[3] memory numbers = [7, 23, 45];
        
        vm.expectRevert("Game not active");
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers);
        
        vm.stopPrank();
    }
    
    function test_EndGame() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        
        // Try to end game before duration
        vm.expectRevert("Game time not elapsed");
        lottery.endGame(1);
        
        // Fast forward time
        vm.warp(block.timestamp + GAME_DURATION + 1);
        
        lottery.endGame(1);
        
        // Check game phase
        (,,,,,,, uint8 phase, , , ) = lottery.games(1);
        assertEq(uint256(phase), 2); // DRAWING phase
        
        vm.stopPrank();
    }
    
    function test_EndGameNotActive() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        // Don't start the game
        
        vm.expectRevert("Game not active");
        lottery.endGame(1);
        
        vm.stopPrank();
    }
    
    function test_EndGameNotOwner() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        vm.expectRevert();
        lottery.endGame(1);
        
        vm.stopPrank();
    }
    
    function test_GetGame() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        vm.stopPrank();
        
        Lottery.LotteryGame memory game = lottery.getGame(1);
        
        assertEq(game.gameId, 1);
        assertEq(game.ticketPrice, TICKET_PRICE);
        assertEq(game.maxTickets, MAX_TICKETS);
        assertEq(uint256(game.phase), 0); // WAITING phase
    }
    
    function test_GetGameTickets() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        uint256[3] memory numbers1 = [7, 23, 45];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers1);
        vm.stopPrank();
        
        vm.startPrank(player2);
        uint256[3] memory numbers2 = [12, 34, 56];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers2);
        vm.stopPrank();
        
        Lottery.PlayerTicket[] memory tickets = lottery.getGameTickets(1);
        
        assertEq(tickets.length, 2);
        assertEq(tickets[0].player, player1);
        assertEq(tickets[1].player, player2);
    }
    
    function test_GetPlayerTickets() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        uint256[3] memory numbers1 = [7, 23, 45];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers1);
        vm.stopPrank();
        
        vm.startPrank(player2);
        uint256[3] memory numbers2 = [12, 34, 56];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers2);
        vm.stopPrank();
        
        uint256[] memory player1Tickets = lottery.getPlayerTickets(1, player1);
        uint256[] memory player2Tickets = lottery.getPlayerTickets(1, player2);
        
        assertEq(player1Tickets.length, 1);
        assertEq(player2Tickets.length, 1);
        assertEq(player1Tickets[0], 0);
        assertEq(player2Tickets[0], 1);
    }
    
    function test_GetPlayerGameHistory() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        uint256[3] memory numbers = [7, 23, 45];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers);
        vm.stopPrank();
        
        uint256[] memory history = lottery.getPlayerGameHistory(player1);
        
        assertEq(history.length, 1);
        assertEq(history[0], 1);
    }
    
    function test_EmergencyWithdraw() public {
        vm.startPrank(owner);
        
        // Fund the contract
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        uint256[3] memory numbers = [7, 23, 45];
        lottery.purchaseTicket{value: TICKET_PRICE}(1, numbers);
        vm.stopPrank();
        
        uint256 contractBalance = address(lottery).balance;
        assertGt(contractBalance, 0);
        
        vm.startPrank(owner);
        lottery.emergencyWithdraw();
        vm.stopPrank();
        
        assertEq(address(lottery).balance, 0);
    }
    
    function test_PauseGame() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        
        lottery.pauseGame(1);
        
        // Check game phase
        (,,,,,,, uint8 phase, , , ) = lottery.games(1);
        assertEq(uint256(phase), 0); // WAITING phase
        
        vm.stopPrank();
    }
    
    function test_PauseGameNotOwner() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        lottery.startGame(1);
        vm.stopPrank();
        
        vm.startPrank(player1);
        
        vm.expectRevert();
        lottery.pauseGame(1);
        
        vm.stopPrank();
    }
    
    function test_PauseGameNotActive() public {
        vm.startPrank(owner);
        lottery.createGame(TICKET_PRICE, MAX_TICKETS, GAME_DURATION);
        // Don't start the game
        
        vm.expectRevert("Game not active");
        lottery.pauseGame(1);
        
        vm.stopPrank();
    }
}
