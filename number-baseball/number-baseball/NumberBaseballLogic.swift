import Foundation

struct GuessRecord: Identifiable, Equatable {
    let id = UUID()
    let guess: String
    let resultText: String
}

enum BaseballError: LocalizedError {
    case notThreeDigits(String)
    case repeatingDigits(String)

    var errorDescription: String? {
        switch self {
        case .notThreeDigits(let msg): return msg
        case .repeatingDigits(let msg): return msg
        }
    }
}

struct NumberBaseballLogic {
    static func generateAnswer() -> String {
        var digits: [Int] = []
        while digits.count < 3 {
            let d = Int.random(in: 0...9)
            if !digits.contains(d) { digits.append(d) }
        }
        return digits.map(String.init).joined()
    }

    static func validateGuess(_ raw: String, loc: LocalizationManager) throws -> String {
        let filtered = raw.filter(\.isNumber)
        guard filtered.count == 3 else {
            throw BaseballError.notThreeDigits(loc.t("error.notThreeDigits"))
        }
        guard Set(filtered).count == 3 else {
            throw BaseballError.repeatingDigits(loc.t("error.repeatingDigits"))
        }
        return filtered
    }

    static func strikeBall(answer: String, guess: String) -> (strike: Int, ball: Int) {
        let a = Array(answer)
        let g = Array(guess)

        var strike = 0
        var ball = 0

        for i in 0..<3 {
            if g[i] == a[i] { strike += 1 }
            else if a.contains(g[i]) { ball += 1 }
        }
        return (strike, ball)
    }

    static func formatResult(strike: Int, ball: Int) -> String {
        if strike == 0 && ball == 0 { return "0" }
        var parts: [String] = []
        if strike > 0 { parts.append("\(strike)S") }
        if ball > 0 { parts.append("\(ball)B") }
        return parts.joined(separator: " ")
    }
}
