import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth

// MARK: - App Config

enum AppConfig {
  /// 공유 링크 URL
  /// - 출시 전: 웹사이트로 연결
  /// - 앱스토어 승인 후: "https://apps.apple.com/app/id{실제ID}" 로 교체
  static let appStoreURL = "https://sinbiroum.com"
}

private enum FirebaseSetup {
  static let shared: Void = {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }()
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    FirebaseSetup.shared
    return true
  }
}

@MainActor
final class AuthGate: ObservableObject {
  @Published var isReady = false
  @Published var authError: String? = nil

  init() {
    FirebaseSetup.shared
    if Auth.auth().currentUser != nil {
      isReady = true
    } else {
      signIn()
    }
  }

  func signIn() {
    authError = nil
    Auth.auth().signInAnonymously { [weak self] result, error in
      Task { @MainActor in
        if let error, result == nil {
          self?.authError = error.localizedDescription
        } else {
          self?.isReady = true
        }
      }
    }
  }
}

@main
struct YourApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var loc = LocalizationManager()
  @StateObject private var authGate = AuthGate()

  var body: some Scene {
    WindowGroup {
      if authGate.isReady {
        MainMenuView()
          .environmentObject(loc)
      } else if let error = authGate.authError {
        VStack(spacing: 16) {
          Image(systemName: "wifi.exclamationmark")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
          Text(error)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
          Button("Retry") { authGate.signIn() }
            .buttonStyle(.borderedProminent)
        }
      } else {
        ProgressView()
      }
    }
  }
}
