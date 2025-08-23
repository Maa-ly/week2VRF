'use client';

import React, { useState, useEffect } from 'react';
import { LotteryResults } from './LotteryResults';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { CONTRACT_ABI, CONTRACT_ADDRESS, GamePhase, DEFAULT_TICKET_PRICE, DEFAULT_MAX_TICKETS, DEFAULT_GAME_DURATION } from '../app/config';
import { parseEther, formatEther } from 'viem';

export interface LotteryState {
  winningNumbers: number[];
  playerNumbers: number[];
  gamePhase: 'waiting' | 'playing' | 'checking' | 'finished';
  matches: number;
  prize: number;
  attempts: number;
}

export const LotteryGame: React.FC = () => {
  const { address, isConnected } = useAccount();
  
  // Check if contract is properly configured
  const isContractConfigured = CONTRACT_ADDRESS && CONTRACT_ADDRESS !== '0x0000000000000000000000000000000000000000';
  
  // Contract read functions
  const { data: currentGameId } = useReadContract({
    address: CONTRACT_ADDRESS as `0x${string}`,
    abi: CONTRACT_ABI,
    functionName: 'currentGameId',
    query: {
      enabled: isContractConfigured,
    },
  });

  const { data: currentGame } = useReadContract({
    address: CONTRACT_ADDRESS as `0x${string}`,
    abi: CONTRACT_ABI,
    functionName: 'getGame',
    args: currentGameId ? [currentGameId] : undefined,
    query: {
      enabled: !!currentGameId && currentGameId > BigInt(0) && isContractConfigured,
    },
  });

  // Contract write functions
  const { writeContract: createGame, data: createGameHash, isPending: isCreatingGame } = useWriteContract();
  const { writeContract: startGameContract, data: startGameHash, isPending: isStartingGame } = useWriteContract();
  const { writeContract: purchaseTicket, data: purchaseTicketHash, isPending: isPurchasingTicket } = useWriteContract();
  const { writeContract: endGameContract, data: endGameHash, isPending: isEndingGame } = useWriteContract();

  // Transaction receipts
  const { isLoading: isCreateGameLoading, isSuccess: isCreateGameSuccess } = useWaitForTransactionReceipt({
    hash: createGameHash,
  });

  const { isLoading: isStartGameLoading, isSuccess: isStartGameSuccess } = useWaitForTransactionReceipt({
    hash: startGameHash,
  });

  const { isLoading: isPurchaseTicketLoading, isSuccess: isPurchaseTicketSuccess } = useWaitForTransactionReceipt({
    hash: purchaseTicketHash,
  });

  const { isLoading: isEndGameLoading, isSuccess: isEndGameSuccess } = useWaitForTransactionReceipt({
    hash: endGameHash,
  });

  // Local state
  const [selectedNumbers, setSelectedNumbers] = useState<number[]>([]);
  const [lotteryState, setLotteryState] = useState<LotteryState>({
    winningNumbers: [],
    playerNumbers: [],
    gamePhase: 'waiting',
    matches: 0,
    prize: 0,
    attempts: 0,
  });

  // Update local state when contract data changes
  useEffect(() => {
    if (currentGame) {
      const gamePhase = currentGame.phase as number;
      let localPhase: 'waiting' | 'playing' | 'checking' | 'finished';
      
      switch (gamePhase) {
        case GamePhase.WAITING:
          localPhase = 'waiting';
          break;
        case GamePhase.ACTIVE:
          localPhase = 'playing';
          break;
        case GamePhase.DRAWING:
          localPhase = 'checking';
          break;
        case GamePhase.FINISHED:
          localPhase = 'finished';
          break;
        default:
          localPhase = 'waiting';
      }

      setLotteryState(prev => ({
        ...prev,
        gamePhase: localPhase,
        winningNumbers: currentGame.winningNumbers.map(num => Number(num)),
      }));
    }
  }, [currentGame]);

  // Handle successful transactions
  useEffect(() => {
    if (isCreateGameSuccess) {
      console.log('Game created successfully!');
    }
  }, [isCreateGameSuccess]);

  useEffect(() => {
    if (isStartGameSuccess) {
      console.log('Game started successfully!');
    }
  }, [isStartGameSuccess]);

  useEffect(() => {
    if (isPurchaseTicketSuccess) {
      console.log('Ticket purchased successfully!');
      setSelectedNumbers([]);
    }
  }, [isPurchaseTicketSuccess]);

  useEffect(() => {
    if (isEndGameSuccess) {
      console.log('Game ended successfully!');
    }
  }, [isEndGameSuccess]);

  // Start new lottery game
  const startNewGame = async () => {
    if (!isConnected) {
      alert('Please connect your wallet first!');
      return;
    }

    if (!isContractConfigured) {
      alert('Contract not configured! Please set NEXT_PUBLIC_LOTTERY_CONTRACT_ADDRESS in your environment variables.');
      return;
    }

    try {
      const ticketPrice = parseEther(DEFAULT_TICKET_PRICE);
      const maxTickets = BigInt(DEFAULT_MAX_TICKETS);
      const duration = BigInt(DEFAULT_GAME_DURATION);

      // Create game
      createGame({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'createGame',
        args: [ticketPrice, maxTickets, duration],
      });
    } catch (error) {
      console.error('Error creating game:', error);
    }
  };

  // Start the created game
  const startGame = async () => {
    if (!currentGameId || currentGameId === BigInt(0)) {
      alert('No game to start!');
      return;
    }

    try {
      startGameContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'startGame',
        args: [currentGameId],
      });
    } catch (error) {
      console.error('Error starting game:', error);
    }
  };

  // Handle number selection
  const handleNumberSelect = (number: number) => {
    if (lotteryState.gamePhase !== 'playing') return;
    
    if (selectedNumbers.includes(number)) {
      setSelectedNumbers(prev => prev.filter(n => n !== number));
    } else if (selectedNumbers.length < 3) {
      setSelectedNumbers(prev => [...prev, number]);
    }
  };

  // Submit lottery ticket
  const submitTicket = async () => {
    if (!isConnected) {
      alert('Please connect your wallet first!');
      return;
    }

    if (selectedNumbers.length !== 3) {
      alert('Please select exactly 3 numbers!');
      return;
    }

    if (!currentGameId || currentGameId === BigInt(0)) {
      alert('No active game!');
      return;
    }

    try {
      const ticketPrice = parseEther(DEFAULT_TICKET_PRICE);
      const numbers = selectedNumbers.map(n => BigInt(n)) as [bigint, bigint, bigint];

      purchaseTicket({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'purchaseTicket',
        args: [currentGameId, numbers],
        value: ticketPrice,
      });
    } catch (error) {
      console.error('Error purchasing ticket:', error);
    }
  };

  // End game (admin function)
  const endGame = async () => {
    if (!currentGameId || currentGameId === BigInt(0)) {
      alert('No game to end!');
      return;
    }

    try {
      endGameContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'endGame',
        args: [currentGameId],
      });
    } catch (error) {
      console.error('Error ending game:', error);
    }
  };

  // Play again
  const playAgain = () => {
    setLotteryState(prev => ({
      ...prev,
      gamePhase: 'waiting',
      matches: 0,
      prize: 0,
    }));
    setSelectedNumbers([]);
  };

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 flex items-center justify-center">
        <div className="text-center text-white">
          <h1 className="text-4xl font-bold mb-4">🎰 Lottery Game</h1>
          <p className="text-xl">Please connect your wallet to play!</p>
        </div>
      </div>
    );
  }

  if (!isContractConfigured) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 flex items-center justify-center">
        <div className="text-center text-white">
          <h1 className="text-4xl font-bold mb-4">🎰 Lottery Game</h1>
          <div className="bg-red-500/20 backdrop-blur-sm rounded-lg p-6 max-w-md">
            <p className="text-xl mb-4">⚠️ Contract Not Configured</p>
            <p className="text-sm text-red-200 mb-4">
              Please set NEXT_PUBLIC_LOTTERY_CONTRACT_ADDRESS in your environment variables.
            </p>
            <p className="text-xs text-gray-300">
              Current address: {CONTRACT_ADDRESS}
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 p-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-5xl font-bold text-white mb-4">🎰 Lottery Game 🎰</h1>
          <p className="text-xl text-blue-200">
            Pick 3 numbers between 1-100 and try to match the winning combination!
          </p>
          
          {/* Game Status */}
          {currentGame && (
            <div className="mt-4 p-4 bg-white/10 backdrop-blur-sm rounded-lg">
              <div className="text-white">
                <p>Game ID: {currentGameId?.toString()}</p>
                <p>Phase: {GamePhase[currentGame.phase as number]}</p>
                <p>Tickets Sold: {currentGame.ticketsSold.toString()}</p>
                <p>Prize Pool: {formatEther(currentGame.totalPrizePool)} ETH</p>
              </div>
            </div>
          )}
        </div>

        {lotteryState.gamePhase === 'waiting' && (
          <div className="text-center space-y-4">
            <button
              onClick={startNewGame}
              disabled={isCreatingGame || isCreateGameLoading}
              className="px-8 py-4 bg-green-600 text-white text-2xl rounded-lg hover:bg-green-700 transition-colors shadow-2xl hover:shadow-green-500/50 disabled:opacity-50"
            >
              {isCreatingGame || isCreateGameLoading ? 'Creating Game...' : '🎯 Create New Lottery Game'}
            </button>
            
            {currentGameId && currentGameId > BigInt(0) && (
              <button
                onClick={startGame}
                disabled={isStartingGame || isStartGameLoading}
                className="px-8 py-4 bg-blue-600 text-white text-2xl rounded-lg hover:bg-blue-700 transition-colors shadow-2xl hover:shadow-blue-500/50 disabled:opacity-50 ml-4"
              >
                {isStartingGame || isStartGameLoading ? 'Starting Game...' : '🚀 Start Game'}
              </button>
            )}
          </div>
        )}

        {lotteryState.gamePhase === 'playing' && (
          <div className="space-y-6">
            {/* Instructions */}
            <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6 text-center">
              <h2 className="text-2xl font-bold text-white mb-2">Select Your Numbers</h2>
              <p className="text-blue-200">
                Click on 3 numbers between 1-100. Selected numbers will be highlighted.
              </p>
              <div className="mt-4 text-lg text-yellow-300">
                Selected: {selectedNumbers.length}/3
              </div>
              <div className="mt-4 text-lg text-green-300">
                Ticket Price: {DEFAULT_TICKET_PRICE} ETH
              </div>
            </div>

            {/* Number Grid */}
            <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6">
              <div className="grid grid-cols-10 gap-2">
                {Array.from({ length: 100 }, (_, i) => {
                  const number = i + 1;
                  const isSelected = selectedNumbers.includes(number);
                  return (
                    <button
                      key={number}
                      onClick={() => handleNumberSelect(number)}
                      className={`
                        w-12 h-12 rounded-lg font-bold text-lg transition-all duration-200
                        ${isSelected
                          ? 'bg-yellow-500 text-black shadow-lg scale-110'
                          : 'bg-white/20 text-white hover:bg-white/30 hover:scale-105'
                        }
                      `}
                    >
                      {number}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Submit Button */}
            <div className="text-center">
              <button
                onClick={submitTicket}
                disabled={selectedNumbers.length !== 3 || isPurchasingTicket || isPurchaseTicketLoading}
                className={`
                  px-8 py-4 text-xl font-bold rounded-lg transition-all duration-200
                  ${selectedNumbers.length === 3 && !isPurchasingTicket && !isPurchaseTicketLoading
                    ? 'bg-red-600 text-white hover:bg-red-700 shadow-2xl hover:shadow-red-500/50'
                    : 'bg-gray-500 text-gray-300 cursor-not-allowed'
                  }
                `}
              >
                {isPurchasingTicket || isPurchaseTicketLoading ? 'Processing...' : '🎫 Submit Lottery Ticket'}
              </button>
            </div>

            {/* Admin Controls */}
            <div className="text-center">
              <button
                onClick={endGame}
                disabled={isEndingGame || isEndGameLoading}
                className="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50"
              >
                {isEndingGame || isEndGameLoading ? 'Ending Game...' : 'End Game (Admin)'}
              </button>
            </div>
          </div>
        )}

        {lotteryState.gamePhase === 'checking' && (
          <div className="text-center text-white">
            <h2 className="text-3xl font-bold mb-4">🎲 Generating Winning Numbers...</h2>
            <p className="text-xl">Please wait while we generate the winning numbers using blockchain randomness.</p>
          </div>
        )}

        {lotteryState.gamePhase === 'finished' && (
          <LotteryResults
            lotteryState={lotteryState}
            onPlayAgain={playAgain}
          />
        )}

        {/* Game Stats */}
        {lotteryState.attempts > 0 && (
          <div className="mt-8 bg-white/10 backdrop-blur-sm rounded-lg p-6">
            <h3 className="text-2xl font-bold text-white mb-4 text-center">Game Statistics</h3>
            <div className="grid grid-cols-3 gap-4 text-center">
              <div>
                <div className="text-3xl font-bold text-blue-400">{lotteryState.attempts}</div>
                <div className="text-blue-200">Total Attempts</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-green-400">{lotteryState.prize}</div>
                <div className="text-green-200">Total Winnings</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-yellow-400">
                  {lotteryState.attempts > 0 ? Math.round((lotteryState.prize / lotteryState.attempts) * 100) / 100 : 0}
                </div>
                <div className="text-yellow-200">Average per Game</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
