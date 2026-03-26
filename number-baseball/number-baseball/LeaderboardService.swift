import SwiftUI
import Combine
import FirebaseAuth
import FirebaseDatabase

@MainActor
final class LeaderboardService: ObservableObject {

    @Published var soloEntries: [SoloLeaderboardEntry] = []
    @Published var leagueEntries: [LeagueLeaderboardEntry] = []
    @Published var isLoading = false

    /// Solo mode: only record scores with attempts <= this threshold
    static let soloExcellentThreshold = 7

    private let db = Database.database().reference()

    // MARK: - Solo Leaderboard

    /// Submit a solo score to Firebase (only if attempts <= threshold).
    func submitSoloScore(attempts: Int, displayName: String) {
        guard attempts >= 1, attempts <= Self.soloExcellentThreshold else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let name = displayName.isEmpty ? "Anonymous" : displayName
        let entry: [String: Any] = [
            "uid": uid,
            "displayName": name,
            "attempts": attempts,
            "timestamp": ServerValue.timestamp(),
        ]

        db.child("leaderboards/solo").childByAutoId().setValue(entry) { error, _ in
            if let error {
                print("[LeaderboardService] submitSoloScore failed: \(error)")
            }
        }
    }

    /// Fetch top solo scores (fewest attempts first).
    func fetchSoloLeaderboard(limit: Int = 50) {
        isLoading = true
        db.child("leaderboards/solo")
            .queryOrdered(byChild: "attempts")
            .queryLimited(toFirst: UInt(limit))
            .observeSingleEvent(of: .value) { [weak self] snap in
                Task { @MainActor in
                    guard let self else { return }
                    var entries: [SoloLeaderboardEntry] = []

                    for child in snap.children {
                        guard let childSnap = child as? DataSnapshot,
                              let dict = childSnap.value as? [String: Any],
                              let uid = dict["uid"] as? String,
                              let name = dict["displayName"] as? String,
                              let attempts = dict["attempts"] as? Int,
                              let ts = dict["timestamp"] as? Int64
                        else { continue }

                        entries.append(SoloLeaderboardEntry(
                            id: childSnap.key,
                            uid: uid,
                            displayName: name,
                            attempts: attempts,
                            timestamp: ts
                        ))
                    }

                    self.soloEntries = entries
                    self.isLoading = false
                }
            }
    }

    // MARK: - League Leaderboard

    /// Update league leaderboard entry after winning a CPU league match.
    func updateLeagueEntry(level: Int, displayName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let name = displayName.isEmpty ? "Anonymous" : displayName
        let ref = db.child("leaderboards/league/\(uid)")

        ref.observeSingleEvent(of: .value) { snap in
            var currentHighest = 0
            var currentWins = 0
            var existingFirstWinAt: Any?

            if let dict = snap.value as? [String: Any] {
                currentHighest = dict["highestLevel"] as? Int ?? 0
                currentWins = dict["totalWins"] as? Int ?? 0
                existingFirstWinAt = dict["firstWinAt"]
            }

            let newHighest = max(currentHighest, level)
            let newWins = currentWins + 1

            var updates: [String: Any] = [
                "displayName": name,
                "highestLevel": newHighest,
                "totalWins": newWins,
                "updatedAt": ServerValue.timestamp(),
            ]

            // firstWinAt: set only once on the very first league win
            if existingFirstWinAt == nil {
                updates["firstWinAt"] = ServerValue.timestamp()
            }

            // lastWinAt: update whenever a new highest level is reached
            if level >= currentHighest {
                updates["lastWinAt"] = ServerValue.timestamp()
            }

            ref.updateChildValues(updates) { error, _ in
                if let error {
                    print("[LeaderboardService] updateLeagueEntry failed: \(error)")
                }
            }
        }
    }

    /// Fetch league leaderboard (highest level first, then most wins).
    func fetchLeagueLeaderboard(limit: Int = 50) {
        isLoading = true
        db.child("leaderboards/league")
            .queryOrdered(byChild: "highestLevel")
            .queryLimited(toLast: UInt(limit))
            .observeSingleEvent(of: .value) { [weak self] snap in
                Task { @MainActor in
                    guard let self else { return }
                    var entries: [LeagueLeaderboardEntry] = []

                    for child in snap.children {
                        guard let childSnap = child as? DataSnapshot,
                              let dict = childSnap.value as? [String: Any],
                              let name = dict["displayName"] as? String,
                              let highest = dict["highestLevel"] as? Int,
                              let wins = dict["totalWins"] as? Int
                        else { continue }

                        let ts = dict["updatedAt"] as? Int64 ?? 0
                        let firstWin = dict["firstWinAt"] as? Int64
                        let lastWin = dict["lastWinAt"] as? Int64

                        entries.append(LeagueLeaderboardEntry(
                            uid: childSnap.key,
                            displayName: name,
                            highestLevel: highest,
                            totalWins: wins,
                            firstWinAt: firstWin,
                            lastWinAt: lastWin,
                            updatedAt: ts
                        ))
                    }

                    // Reverse: Firebase limitToLast gives ascending, we want descending
                    // Sort by highestLevel desc, then totalWins desc
                    entries.sort { a, b in
                        if a.highestLevel != b.highestLevel {
                            return a.highestLevel > b.highestLevel
                        }
                        return a.totalWins > b.totalWins
                    }

                    self.leagueEntries = entries
                    self.isLoading = false
                }
            }
    }
}
