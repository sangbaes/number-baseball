import SwiftUI
import Combine
import FirebaseAuth
import FirebaseDatabase

@MainActor
final class ProgressionManager: ObservableObject {
  @Published var unlockedLevels: Set<Int> = [1]
  @Published var keyExpirations: [Int: Date] = [:]   // level -> expiration date
  @Published var isLoaded = false

  /// Key expiration TTL: 7 days
  static let keyTTLSeconds: TimeInterval = 7 * 24 * 60 * 60

  /// Key mapping: Level N key unlocks Level N+1
  private static let levelKeys: [Int: String] = [
    1: "L01_KEY",
    2: "L02_KEY",
    3: "L03_KEY",
    4: "L04_KEY",
    5: "L05_KEY",
    6: "L06_KEY",
  ]

  static let levels: [LeagueLevel] = [
    LeagueLevel(level: 1, name: "Beginner",     emoji: "🥉", groupCode: "L01"),
    LeagueLevel(level: 2, name: "Intermediate",  emoji: "🥈", groupCode: "L02"),
    LeagueLevel(level: 3, name: "Advanced",      emoji: "🥇", groupCode: "L03"),
    LeagueLevel(level: 4, name: "Expert",        emoji: "💎", groupCode: "L04"),
    LeagueLevel(level: 5, name: "Master",        emoji: "👑", groupCode: "L05"),
    LeagueLevel(level: 6, name: "Grandmaster",   emoji: "🔥", groupCode: "L06"),
  ]

  // MARK: - Sync from Firebase

  func syncFromFirebase() {
    guard let uid = Auth.auth().currentUser?.uid else {
      loadFromCache()
      return
    }
    let ref = Database.database().reference().child("playerProgress/\(uid)")
    ref.observeSingleEvent(of: .value) { [weak self] snap in
      guard let self else { return }
      Task { @MainActor in
        var unlocked: Set<Int> = [1]   // Level 1 always open
        var expirations: [Int: Date] = [:]
        let now = Date()

        if let dict = snap.value as? [String: Any],
           let keys = dict["keys"] as? [String: Any] {
          for (levelNum, keyName) in Self.levelKeys {
            guard let value = keys[keyName] else { continue }
            let nextLevel = levelNum + 1

            if let timestamp = value as? Double {
              // Timestamp-based key (milliseconds since epoch)
              let grantedAt = Date(timeIntervalSince1970: timestamp / 1000.0)
              let expiresAt = grantedAt.addingTimeInterval(Self.keyTTLSeconds)
              if now < expiresAt {
                unlocked.insert(nextLevel)
                expirations[nextLevel] = expiresAt
              }
            } else if value is Bool {
              // Legacy key (true) — treat as just earned
              unlocked.insert(nextLevel)
            }
          }
        }

        self.unlockedLevels = unlocked
        self.keyExpirations = expirations
        self.cacheLocally()
        self.isLoaded = true
      }
    }
  }

  func isUnlocked(_ level: Int) -> Bool {
    unlockedLevels.contains(level)
  }

  /// Returns remaining seconds before the key for a level expires.
  /// Returns nil for Level 1 (always unlocked) or levels without expiration.
  func remainingTime(for level: Int) -> TimeInterval? {
    guard let expires = keyExpirations[level] else { return nil }
    let remaining = expires.timeIntervalSince(Date())
    return remaining > 0 ? remaining : nil
  }

  func refreshProgression() {
    syncFromFirebase()
  }

  // MARK: - Key Granting

  /// Grant progression key after winning a league match.
  /// Returns true if successfully written to Firebase.
  func grantKey(level: Int, roomCode: String) async -> Bool {
    guard let uid = Auth.auth().currentUser?.uid else { return false }
    guard let keyName = Self.levelKeys[level] else { return false }

    let nextLevel = level + 1
    let ref = Database.database().reference().child("playerProgress/\(uid)")

    // Build updated unlocked set
    var newUnlocked = unlockedLevels
    if nextLevel <= Self.levels.count {
      newUnlocked.insert(nextLevel)
    }

    let updates: [String: Any] = [
      "unlockedLevels": Array(newUnlocked).sorted(),
      "keys/\(keyName)": ServerValue.timestamp(),
      "matchHistory/\(roomCode)/level": level,
      "matchHistory/\(roomCode)/result": "win",
      "matchHistory/\(roomCode)/completedAt": ServerValue.timestamp(),
      "updatedAt": ServerValue.timestamp(),
    ]

    return await withCheckedContinuation { continuation in
      ref.updateChildValues(updates) { [weak self] error, _ in
        Task { @MainActor in
          if let error {
            print("[ProgressionManager] grantKey failed: \(error)")
            continuation.resume(returning: false)
          } else {
            self?.unlockedLevels = newUnlocked
            if nextLevel <= Self.levels.count {
              self?.keyExpirations[nextLevel] = Date().addingTimeInterval(Self.keyTTLSeconds)
            }
            self?.cacheLocally()
            continuation.resume(returning: true)
          }
        }
      }
    }
  }

  /// Record a loss in match history.
  func recordLoss(level: Int, roomCode: String) {
    guard let uid = Auth.auth().currentUser?.uid else { return }
    let ref = Database.database().reference().child("playerProgress/\(uid)")
    ref.updateChildValues([
      "matchHistory/\(roomCode)/level": level,
      "matchHistory/\(roomCode)/result": "loss",
      "matchHistory/\(roomCode)/completedAt": ServerValue.timestamp(),
      "updatedAt": ServerValue.timestamp(),
    ])
  }

  // MARK: - CPU Room (local CPU — no remote workers)

  /// Create a room for local CPU game at the given level.
  func findAndJoinBotRoom(
    level: Int,
    playerName: String,
    svc: RoomService,
    loc: LocalizationManager,
    completion: @escaping (Bool) -> Void
  ) {
    let groupCode = Self.levels.first(where: { $0.level == level })?.groupCode ?? "L01"
    let cpuName = CPUPlayer.levelConfigs[level]?.cpuName ?? "CPU"

    print("[LEAGUE] Creating local CPU room: level=\(level), groupCode=\(groupCode)")

    svc.createLocalCPURoom(
      cpuName: cpuName,
      level: level,
      groupCode: groupCode,
      playerName: playerName
    )

    GameAnalytics.roomJoined(method: "league_level_\(level)")
    completion(true)
  }

  // MARK: - Private

  private func cacheLocally() {
    UserDefaults.standard.set(Array(unlockedLevels), forKey: "unlockedLevels")
    // Cache key expiration dates as [levelString: timeIntervalSince1970]
    let expDict = keyExpirations.reduce(into: [String: Double]()) { dict, pair in
      dict[String(pair.key)] = pair.value.timeIntervalSince1970
    }
    UserDefaults.standard.set(expDict, forKey: "keyExpirations")
  }

  private func loadFromCache() {
    var unlocked: Set<Int> = [1]
    var expirations: [Int: Date] = [:]
    let now = Date()

    if let expDict = UserDefaults.standard.dictionary(forKey: "keyExpirations") as? [String: Double] {
      for (levelStr, timestamp) in expDict {
        guard let level = Int(levelStr) else { continue }
        let expiresAt = Date(timeIntervalSince1970: timestamp)
        if now < expiresAt {
          unlocked.insert(level)
          expirations[level] = expiresAt
        }
      }
    } else if let cached = UserDefaults.standard.array(forKey: "unlockedLevels") as? [Int] {
      // Legacy cache without expiration data — keep all unlocked
      unlocked = Set(cached)
    }

    unlockedLevels = unlocked
    keyExpirations = expirations
    isLoaded = true
  }
}
