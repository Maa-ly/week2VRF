// define your interface
// 1. used to join a game
//2. playercount cant be > 4
//3. game shouldnt be started


export interface JoinGame {
    gameStarted: boolean
    playerCount: number[]
}