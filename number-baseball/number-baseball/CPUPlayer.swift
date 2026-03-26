import Foundation
import FirebaseDatabase

/// Manages CPU turn-taking in league mode.
/// Observes RoomService state and submits guesses to Firebase when it's CPU's turn.
@MainActor
final class CPUPlayer {

  // MARK: - Level Configuration

  struct LevelConfig {
    let strategy: String        // "random", "elimination", "entropy"
    let errorRate: Double       // 0.0 to 1.0
    let guessDelay: TimeInterval
    let cpuName: String
  }

  static let levelConfigs: [Int: LevelConfig] = [
    1: LevelConfig(strategy: "random",      errorRate: 0.0,  guessDelay: 3.5, cpuName: "CPU-Beginner"),
    2: LevelConfig(strategy: "elimination", errorRate: 0.4,  guessDelay: 3.0, cpuName: "CPU-Intermediate"),
    3: LevelConfig(strategy: "elimination", errorRate: 0.0,  guessDelay: 2.0, cpuName: "CPU-Advanced"),
    4: LevelConfig(strategy: "entropy",     errorRate: 0.15, guessDelay: 1.5, cpuName: "CPU-Expert"),
    5: LevelConfig(strategy: "entropy",     errorRate: 0.0,  guessDelay: 1.0, cpuName: "CPU-Master"),
    6: LevelConfig(strategy: "minimax",     errorRate: 0.0,  guessDelay: 0.7, cpuName: "CPU-Grandmaster"),
  ]

  // MARK: - State

  private var strategy: (any CPUStrategyProtocol)?
  private var history: [CPUGuessResult] = []
  private var currentLevel: Int = 0
  private var isActive = false
  private var pendingGuessTask: Task<Void, Never>?

  // MARK: - Public API

  /// Start CPU player for a given level.
  func start(level: Int) {
    currentLevel = level
    history = []
    isActive = true
    strategy = Self.makeStrategy(for: level)
    strategy?.reset()
  }

  /// Stop the CPU player.
  func stop() {
    isActive = false
    pendingGuessTask?.cancel()
    pendingGuessTask = nil
    history = []
    strategy = nil
  }

  /// Called when room state changes. Checks if it's CPU's turn and submits a guess.
  func onRoomStateChanged(svc: RoomService) {
    guard isActive else { return }
    guard svc.status == "playing" else { return }
    guard svc.outcome == nil else { return }
    guard svc.currentTurn == "p1" else { return }
    guard svc.turnSecret != nil else { return }

    // Avoid duplicate submissions
    guard pendingGuessTask == nil else { return }

    // Check if p1 already submitted for the current round
    let maxRound = svc.rounds.keys.max() ?? 0
    if maxRound > 0, let round = svc.rounds[maxRound], round.guessFrom["p1"] != nil {
      return
    }

    let config = Self.levelConfigs[currentLevel] ?? Self.levelConfigs[1]!
    let delay = config.guessDelay + Double.random(in: 0...1.0)
    let roomCode = svc.roomCode
    let turnSecret = svc.turnSecret!

    pendingGuessTask = Task { [weak self] in
      // Artificial thinking delay
      try? await Task.sleep(for: .seconds(delay))

      guard let self else { return }
      guard !Task.isCancelled, self.isActive else {
        self.pendingGuessTask = nil
        return
      }

      // Re-verify it's still CPU's turn
      guard svc.currentTurn == "p1", svc.outcome == nil else {
        self.pendingGuessTask = nil
        return
      }

      // Compute guess
      guard var strat = self.strategy else {
        self.pendingGuessTask = nil
        return
      }
      let guess = strat.nextGuess(history: self.history)
      self.strategy = strat

      let (s, b) = BaseballLogic.strikeBall(secret: turnSecret, guess: guess)
      self.history.append(CPUGuessResult(guess: guess, strike: s, ball: b))

      // Submit to Firebase
      let nextRound = (svc.rounds.keys.max() ?? 0) + 1
      let db = Database.database().reference()
      let rr = db.child("rooms").child(roomCode)

      var updates: [String: Any] = [
        "rounds/\(nextRound)/guessFrom/p1/value": guess,
        "rounds/\(nextRound)/guessFrom/p1/ts": ServerValue.timestamp(),
        "rounds/\(nextRound)/resultFor/p1/strike": s,
        "rounds/\(nextRound)/resultFor/p1/ball": b,
        "rounds/\(nextRound)/resultFor/p1/ts": ServerValue.timestamp(),
        "currentTurn": "p2",
      ]

      if s == 3 {
        updates["solvedAt/p1"] = ServerValue.timestamp()
      }

      rr.updateChildValues(updates) { _, _ in }
      self.pendingGuessTask = nil
    }
  }

  // MARK: - Private

  private static func makeStrategy(for level: Int) -> any CPUStrategyProtocol {
    let config = levelConfigs[level] ?? levelConfigs[1]!

    let base: any CPUStrategyProtocol
    switch config.strategy {
    case "elimination": base = EliminationStrategy()
    case "entropy":     base = EntropyStrategy()
    case "minimax":     base = MinimaxStrategy()
    default:            base = RandomStrategy()
    }

    if config.errorRate > 0 {
      return NoisyStrategy(inner: base, errorRate: config.errorRate)
    }
    return base
  }
}
