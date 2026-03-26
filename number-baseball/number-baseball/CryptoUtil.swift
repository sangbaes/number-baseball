import Foundation
import CryptoKit

enum CryptoUtil {
  static func sha256Hex(_ s: String) -> String {
    let data = Data(s.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  static func randomSalt(length: Int = 16) -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    return String((0..<length).compactMap { _ in chars.randomElement() })
  }
}
