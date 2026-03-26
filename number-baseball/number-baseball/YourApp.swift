import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth

// MARK: - App Config

enum AppConfig {
  /// 공유 링크 URL (App Store)
  static let appStoreURL = "https://apps.apple.com/kr/app/number-baseball-2x/id6759283815"
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
