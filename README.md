# Lottery Game Frontend & Smart Contract

A fully functional lottery game built with Next.js, React, Tailwind CSS, and Solidity smart contracts.

## Features

- **Lottery Game Mechanics**: 
  - Generate 3 random winning numbers (1-100)
  - Player selects 3 numbers from 1-100
  - Check for matches and award prizes
  - Multiple prize tiers based on matches
- **Interactive UI**: 
  - Beautiful number grid (1-100)
  - Visual number selection with highlighting
  - Results display with animations
  - Game statistics tracking
- **Smart Contract Integration**: 
  - Blockchain-based lottery management
  - Secure random number generation
  - Automated prize distribution
  - Multi-game support

## Game Rules

1. **Objective**: Match as many numbers as possible with the winning combination
2. **Game Flow**:
   - Click "Start New Lottery Game"
   - Select 3 numbers from the 1-100 grid
   - Submit your lottery ticket
   - See results and prizes
   - Play again or start new game
3. **Prize Structure**:
   - **3 Matches**: $1,000 (Jackpot!)
   - **2 Matches**: $100 (Second Prize)
   - **1 Match**: $10 (Third Prize)
   - **0 Matches**: $0 (Better luck next time!)

## Smart Contract Features

### Core Functionality
- **Game Management**: Create, start, pause, and end lottery games
- **Ticket System**: Purchase tickets with ETH, validate number selections
- **Random Number Generation**: Use blockchain-based VRF for fair randomness
- **Prize Distribution**: Automated calculation and distribution of prizes
- **Multi-Game Support**: Run multiple lottery games simultaneously

### Game Phases
1. **WAITING**: Game created, waiting to start
2. **ACTIVE**: Players can purchase tickets
3. **DRAWING**: Game ended, generating winning numbers
4. **FINISHED**: Results calculated, prizes can be claimed

### Security Features
- **Access Control**: Only owner can manage games
- **Input Validation**: Ensures valid number selections (1-100, no duplicates)
- **Emergency Functions**: Owner can pause games and withdraw funds
- **Randomness**: Uses Chainlink VRF for provably fair results

## Components

- `LotteryGame`: Main game controller and state management
- `LotteryResults`: Displays results, prizes, and game statistics

## Smart Contract Functions

### Game Management
- `createGame(ticketPrice, maxTickets, duration)`: Create new lottery game
- `startGame(gameId)`: Activate a waiting game
- `endGame(gameId)`: End active game and generate winning numbers
- `pauseGame(gameId)`: Pause active game (emergency)

### Player Actions
- `purchaseTicket(gameId, numbers)`: Buy lottery ticket with 3 numbers
- `claimPrize(gameId, resultIndex)`: Claim won prizes

### View Functions
- `getGame(gameId)`: Get game information
- `getGameTickets(gameId)`: Get all tickets for a game
- `getGameResults(gameId)`: Get results and prizes for a game
- `getPlayerTickets(gameId, player)`: Get player's tickets for a game
- `getPlayerGameHistory(player)`: Get player's game history

## Technical Details

- **Frontend**: Next.js 15 with React 19
- **Styling**: Tailwind CSS with glassmorphism effects
- **State Management**: React hooks with useState
- **TypeScript**: Full type safety for game state and components
- **Smart Contract**: Solidity 0.8.19 with OpenZeppelin patterns
- **Randomness**: Chainlink VRF integration for fair number generation
- **Testing**: Foundry framework with comprehensive test coverage

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   # or
   pnpm install
   ```

2. Run the development server:
   ```bash
   npm run dev
   # or
   pnpm dev
   ```

3. Open [http://localhost:3000](http://localhost:3000) in your browser

## Smart Contract Development

### Prerequisites
- Foundry framework installed
- Solidity 0.8.19+
- Chainlink VRF setup

### Testing
```bash
# Run all tests
forge test

# Run specific test
forge test --match-test test_PurchaseTicket

# Run with verbose output
forge test -vvvv
```

### Deployment
1. Configure environment variables for network and VRF
2. Deploy RandomnessSender contract
3. Deploy Lottery contract with RandomnessSender address
4. Set up VRF subscription and funding

## Integration Points

### Frontend to Smart Contract
- **Wallet Connection**: MetaMask or other Web3 wallets
- **Game State**: Read game phases, ticket counts, results
- **Player Actions**: Purchase tickets, claim prizes
- **Real-time Updates**: Listen to contract events

### Smart Contract Events
- `GameCreated`: New lottery game started
- `TicketPurchased`: Player bought ticket
- `NumbersGenerated`: Winning numbers revealed
- `GameFinished`: Game completed with results
- `PrizeClaimed`: Player claimed prize

## Prize Distribution Algorithm

The smart contract uses a percentage-based prize distribution:
- **Jackpot (3 matches)**: 70% of total prize pool
- **Second Prize (2 matches)**: 20% of total prize pool  
- **Third Prize (1 match)**: 10% of total prize pool

Prizes are distributed equally among winners in each category.

## Security Considerations

- **Randomness**: Uses Chainlink VRF for provably fair results
- **Access Control**: Owner-only functions for game management
- **Input Validation**: Comprehensive validation of player inputs
- **Emergency Controls**: Ability to pause games and withdraw funds
- **Reentrancy Protection**: Safe external calls for prize distribution

## File Structure

```
src/
├── app/
│   ├── page.tsx          # Main lottery game entry point
│   ├── layout.tsx        # App layout
│   └── globals.css       # Global styles
├── components/
│   ├── LotteryGame.tsx   # Main lottery controller
│   └── LotteryResults.tsx # Results display component
└── contract/
    ├── Lottery.sol       # Main lottery smart contract
    └── test/
        └── Lottery.t.sol # Comprehensive test suite
```

## Next Steps

1. **Frontend Integration**: Connect React components to smart contract
2. **Wallet Integration**: Add MetaMask/Web3 wallet support
3. **Game Management**: Implement admin panel for game creation
4. **Multiplayer**: Add support for multiple concurrent games
5. **Analytics**: Track player statistics and game performance

## Contributing

The lottery system is complete with both frontend and smart contract components. Any modifications should maintain the existing game logic, security features, and UI structure.
