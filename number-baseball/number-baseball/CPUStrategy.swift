import Foundation

// MARK: - Candidate Pool

enum CandidatePool {
  /// All 720 valid 3-digit permutations of digits 0-9 with no repeats.
  static let all: [String] = {
    var results: [String] = []
    results.reserveCapacity(720)
    for a in 0...9 {
      for b in 0...9 where b != a {
        for c in 0...9 where c != a && c != b {
          results.append("\(a)\(b)\(c)")
        }
      }
    }
    return results
  }()

  /// Filter candidates that would produce the given (strike, ball) against `guess`.
  static func filter(_ candidates: [String], guess: String, strike: Int, ball: Int) -> [String] {
    candidates.filter { candidate in
      let (s, b) = BaseballLogic.strikeBall(secret: candidate, guess: guess)
      return s == strike && b == ball
    }
  }
}

// MARK: - Guess History Record

struct CPUGuessResult {
  let guess: String
  let strike: Int
  let ball: Int
}

// MARK: - Strategy Protocol

protocol CPUStrategyProtocol {
  var name: String { get }
  mutating func reset()
  mutating func nextGuess(history: [CPUGuessResult]) -> String
}

// MARK: - Random Strategy

struct RandomStrategy: CPUStrategyProtocol {
  var name: String { "Random" }
  func reset() {}
  func nextGuess(history: [CPUGuessResult]) -> String {
    CandidatePool.all.randomElement()!
  }
}

// MARK: - Elimination Strategy

struct EliminationStrategy: CPUStrategyProtocol {
  var name: String { "Elimination" }
  mutating func reset() {}

  func nextGuess(history: [CPUGuessResult]) -> String {
    var candidates = CandidatePool.all
    for gr in history {
      candidates = CandidatePool.filter(candidates, guess: gr.guess, strike: gr.strike, ball: gr.ball)
    }
    if candidates.isEmpty {
      return CandidatePool.all.randomElement()!
    }
    return candidates.randomElement()!
  }
}

// MARK: - Entropy Strategy

struct EntropyStrategy: CPUStrategyProtocol {
  var name: String { "Entropy" }
  mutating func reset() {}

  func nextGuess(history: [CPUGuessResult]) -> String {
    var candidates = CandidatePool.all
    for gr in history {
      candidates = CandidatePool.filter(candidates, guess: gr.guess, strike: gr.strike, ball: gr.ball)
    }

    if candidates.isEmpty { return CandidatePool.all.randomElement()! }
    if candidates.count <= 2 { return candidates.randomElement()! }

    let candidateSet = Set(candidates)

    // Evaluate all remaining candidates + sample of others
    var guessesToEval = candidates
    let others = CandidatePool.all.filter { !candidateSet.contains($0) }
    if others.count > 100 {
      guessesToEval.append(contentsOf: others.shuffled().prefix(100))
    } else {
      guessesToEval.append(contentsOf: others)
    }

    var bestGuess: String?
    var bestEntropy: Double = -1.0
    var bestIsCandidate = false

    for guess in guessesToEval {
      let entropy = Self.computeEntropy(guess: guess, candidates: candidates)
      let isCandidate = candidateSet.contains(guess)
      if entropy > bestEntropy || (entropy == bestEntropy && isCandidate && !bestIsCandidate) {
        bestEntropy = entropy
        bestGuess = guess
        bestIsCandidate = isCandidate
      }
    }

    return bestGuess ?? candidates.randomElement()!
  }

  private static func computeEntropy(guess: String, candidates: [String]) -> Double {
    var counter: [Int: Int] = [:]  // encoded (s*10+b) -> count
    for candidate in candidates {
      let (s, b) = BaseballLogic.strikeBall(secret: candidate, guess: guess)
      let key = s * 10 + b
      counter[key, default: 0] += 1
    }
    let total = Double(candidates.count)
    var entropy = 0.0
    for count in counter.values where count > 0 {
      let p = Double(count) / total
      entropy -= p * log2(p)
    }
    return entropy
  }
}

// MARK: - Minimax Strategy

struct MinimaxStrategy: CPUStrategyProtocol {
  var name: String { "Minimax" }
  mutating func reset() {}

  func nextGuess(history: [CPUGuessResult]) -> String {
    var candidates = CandidatePool.all
    for gr in history {
      candidates = CandidatePool.filter(candidates, guess: gr.guess, strike: gr.strike, ball: gr.ball)
    }

    if candidates.isEmpty { return CandidatePool.all.randomElement()! }
    if candidates.count <= 2 { return candidates.first! }

    let candidateSet = Set(candidates)

    // Evaluate ALL 720 possible guesses — not just remaining candidates
    var bestGuess: String?
    var bestWorstCase = Int.max
    var bestIsCandidate = false

    for guess in CandidatePool.all {
      let worstCase = Self.computeWorstCase(guess: guess, candidates: candidates)
      let isCandidate = candidateSet.contains(guess)

      if worstCase < bestWorstCase ||
         (worstCase == bestWorstCase && isCandidate && !bestIsCandidate) {
        bestWorstCase = worstCase
        bestGuess = guess
        bestIsCandidate = isCandidate
      }
    }

    return bestGuess ?? candidates.first!
  }

  private static func computeWorstCase(guess: String, candidates: [String]) -> Int {
    var counter: [Int: Int] = [:]
    for candidate in candidates {
      let (s, b) = BaseballLogic.strikeBall(secret: candidate, guess: guess)
      let key = s * 10 + b
      counter[key, default: 0] += 1
    }
    return counter.values.max() ?? 0
  }
}

// MARK: - Noisy Strategy Wrapper

struct NoisyStrategy: CPUStrategyProtocol {
  private var inner: CPUStrategyProtocol
  private let errorRate: Double

  var name: String { "\(inner.name) (noise=\(Int(errorRate * 100))%)" }

  init(inner: CPUStrategyProtocol, errorRate: Double) {
    self.inner = inner
    self.errorRate = max(0.0, min(1.0, errorRate))
  }

  mutating func reset() { inner.reset() }

  mutating func nextGuess(history: [CPUGuessResult]) -> String {
    if Double.random(in: 0..<1) < errorRate {
      return CandidatePool.all.randomElement()!
    }
    return inner.nextGuess(history: history)
  }
}
