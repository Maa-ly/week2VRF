
// Game data interface

export interface GameData {
  status: boolean
  gameStarted: boolean
  gameEnded: boolean
  roundStartTime?: string | null;
  selectionTimeLimit: number;
  createdAt: Date;
  updatedAt: Date;
}


