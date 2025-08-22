'use client';

import React from 'react';
import { LotteryState } from './LotteryGame';

interface LotteryResultsProps {
  lotteryState: LotteryState;
  onPlayAgain: () => void;
}

export const LotteryResults: React.FC<LotteryResultsProps> = ({
  lotteryState,
  onPlayAgain,
}) => {
  const { winningNumbers, playerNumbers, matches, prize } = lotteryState;

  const getResultMessage = () => {
    if (matches === 3) return "🎉 JACKPOT! You got all 3 numbers! 🎉";
    if (matches === 2) return "🎊 Great! You matched 2 numbers! 🎊";
    if (matches === 1) return "🎯 Good! You matched 1 number! 🎯";
    return "😔 No matches this time. Better luck next time! 😔";
  };

  const getResultColor = () => {
    if (matches === 3) return "text-yellow-400";
    if (matches === 2) return "text-green-400";
    if (matches === 1) return "text-blue-400";
    return "text-red-400";
  };

  return (
    <div className="space-y-6">
      {/* Results Header */}
      <div className="text-center">
        <h2 className={`text-4xl font-bold mb-4 ${getResultColor()}`}>
          {getResultMessage()}
        </h2>
        <div className="text-2xl text-white">
          Prize: <span className="text-yellow-400 font-bold">${prize}</span>
        </div>
      </div>

      {/* Numbers Comparison */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Winning Numbers */}
        <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6">
          <h3 className="text-2xl font-bold text-white mb-4 text-center">🏆 Winning Numbers</h3>
          <div className="flex justify-center gap-3">
            {winningNumbers.map((number, index) => (
              <div
                key={index}
                className="w-16 h-16 bg-green-500 text-white text-2xl font-bold rounded-full flex items-center justify-center shadow-lg"
              >
                {number}
              </div>
            ))}
          </div>
        </div>

        {/* Player Numbers */}
        <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6">
          <h3 className="text-2xl font-bold text-white mb-4 text-center">🎫 Your Numbers</h3>
          <div className="flex justify-center gap-3">
            {playerNumbers.map((number, index) => {
              const isMatch = winningNumbers.includes(number);
              return (
                <div
                  key={index}
                  className={`
                    w-16 h-16 text-2xl font-bold rounded-full flex items-center justify-center shadow-lg
                    ${isMatch
                      ? 'bg-green-500 text-white'
                      : 'bg-red-500 text-white'
                    }
                  `}
                >
                  {number}
                  {isMatch && <span className="text-sm ml-1">✓</span>}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Match Details */}
      <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6 text-center">
        <h3 className="text-2xl font-bold text-white mb-4">Match Results</h3>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <div className="text-3xl font-bold text-blue-400">{matches}</div>
            <div className="text-blue-200">Numbers Matched</div>
          </div>
          <div>
            <div className="text-3xl font-bold text-green-400">{prize}</div>
            <div className="text-green-200">Prize Won</div>
          </div>
          <div>
            <div className="text-3xl font-bold text-yellow-400">
              {matches === 3 ? '100%' : matches === 2 ? '66%' : matches === 1 ? '33%' : '0%'}
            </div>
            <div className="text-yellow-200">Success Rate</div>
          </div>
        </div>
      </div>

      {/* Prize Breakdown */}
      <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6">
        <h3 className="text-2xl font-bold text-white mb-4 text-center">💰 Prize Structure</h3>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="bg-green-500/20 rounded-lg p-4">
            <div className="text-2xl font-bold text-green-400">3 Matches</div>
            <div className="text-green-200">$1,000</div>
            <div className="text-sm text-green-300">Jackpot!</div>
          </div>
          <div className="bg-blue-500/20 rounded-lg p-4">
            <div className="text-2xl font-bold text-blue-400">2 Matches</div>
            <div className="text-blue-200">$100</div>
            <div className="text-sm text-blue-300">Second Prize</div>
          </div>
          <div className="bg-yellow-500/20 rounded-lg p-4">
            <div className="text-2xl font-bold text-yellow-400">1 Match</div>
            <div className="text-yellow-200">$10</div>
            <div className="text-sm text-yellow-300">Third Prize</div>
          </div>
        </div>
      </div>

      {/* Play Again Button */}
      <div className="text-center">
        <button
          onClick={onPlayAgain}
          className="px-8 py-4 bg-purple-600 text-white text-xl font-bold rounded-lg hover:bg-purple-700 transition-colors shadow-2xl hover:shadow-purple-500/50"
        >
          🎰 Play Another Lottery Game
        </button>
      </div>
    </div>
  );
};
