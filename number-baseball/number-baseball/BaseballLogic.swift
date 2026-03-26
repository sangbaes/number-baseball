import Foundation

enum BaseballLogic {
  static func validate3UniqueDigits(_ s: String) -> Bool {
    let digits = s.filter(\.isNumber)
    return digits.count == 3 && Set(digits).count == 3
  }

  /// TextField onChange에서 사용: 숫자만, 중복 제거, 최대 3자리
  static func filterUniqueDigits(_ input: String) -> String {
    var seen = Set<Character>()
    var result = ""
    for ch in input where ch.isNumber {
      if !seen.contains(ch) {
        seen.insert(ch)
        result.append(ch)
      }
      if result.count >= 3 { break }
    }
    return result
  }

  /// 중복 없는 랜덤 3자리 숫자 생성 (0~9)
  static func randomSecret() -> String {
    var digits = Array(0...9)
    digits.shuffle()
    return digits.prefix(3).map { String($0) }.joined()
  }

  static func strikeBall(secret: String, guess: String) -> (strike: Int, ball: Int) {
    let a = Array(secret)
    let g = Array(guess)
    var strike = 0
    var ball = 0
    for i in 0..<3 {
      if g[i] == a[i] { strike += 1 }
      else if a.contains(g[i]) { ball += 1 }
    }
    return (strike, ball)
  }
}
