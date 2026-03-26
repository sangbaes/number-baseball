import Foundation

// MARK: - Solo Leaderboard

struct SoloLeaderboardEntry: Identifiable, Equatable {
    var id: String              // Firebase push key
    var uid: String
    var displayName: String
    var attempts: Int
    var timestamp: Int64
}

// MARK: - League Leaderboard

struct LeagueLeaderboardEntry: Identifiable, Equatable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var highestLevel: Int
    var totalWins: Int
    var firstWinAt: Int64?     // timestamp of first Level 1 win
    var lastWinAt: Int64?      // timestamp of highest level win
    var updatedAt: Int64

    /// Hours from first win to highest level clear. nil if only 1 level cleared.
    var clearHours: Double? {
        guard let first = firstWinAt, let last = lastWinAt,
              last > first, highestLevel > 1 else { return nil }
        return Double(last - first) / 1000.0 / 3600.0
    }
}
