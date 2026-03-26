import Foundation

struct PlayerInfo: Equatable {
  var name: String
  var connected: Bool
}

struct Guess: Equatable {
  var value: String
  var ts: Int64?
}

struct Result: Equatable {
  var strike: Int
  var ball: Int
  var ts: Int64?
}

struct RoundState: Equatable {
  var guessFrom: [String: Guess] = [:]   // p1/p2
  var resultFor: [String: Result] = [:]  // p1/p2 (각 플레이어가 "상대 정답"을 맞춘 결과)
}

struct OutcomeState: Equatable {
  var type: String        // win/draw/forfeit/invalid
  var winnerId: String?   // p1/p2
  var reason: String?     // time/hash_mismatch/disconnect/...
}

struct PublicRoomEntry: Identifiable, Equatable {
  var id: String { roomCode }
  var roomCode: String
  var hostName: String
  var gameMode: String      // "simultaneous" | "turn"
  var groupCode: String
  var createdAt: Int64?
  var playerCount: Int      // 1 = joinable, 2 = full
}

struct GroupEntry: Identifiable, Equatable {
  var id: String { groupCode }
  var groupCode: String
  var roomCount: Int
}

// MARK: - League Models

struct LeagueLevel: Identifiable, Equatable {
  var id: Int { level }
  var level: Int
  var name: String
  var emoji: String
  var groupCode: String
}
