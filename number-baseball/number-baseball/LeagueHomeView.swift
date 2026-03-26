import SwiftUI

struct LeagueHomeView: View {
  @EnvironmentObject var progression: ProgressionManager
  @EnvironmentObject var loc: LocalizationManager
  @EnvironmentObject var svc: RoomService
  @EnvironmentObject var leaderboard: LeaderboardService
  @Environment(\.dismiss) private var dismiss

  @State private var playerName: String = ""
  @State private var showNamePrompt = false
  @State private var selectedLevel: Int = 0
  @State private var navigateToGame = false
  @State private var isJoining = false

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Header
        VStack(spacing: 6) {
          Text("\u{1F3C6}")
            .font(.system(size: 48))
          Text(loc.t("league.title"))
            .font(.system(size: 28, weight: .bold, design: .rounded))
          Text(loc.t("league.desc"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)

        // Level cards (hide bonus levels from main list)
        ForEach(ProgressionManager.levels.filter { $0.level <= 5 }) { level in
          LevelCard(
            level: level,
            isUnlocked: progression.isUnlocked(level.level),
            remainingTime: progression.remainingTime(for: level.level),
            isJoining: isJoining && selectedLevel == level.level,
            loc: loc
          ) {
            onLevelTapped(level.level)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .navigationTitle(loc.t("league.title"))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      progression.refreshProgression()
      playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
    }
    .alert(loc.t("league.enterName"), isPresented: $showNamePrompt) {
      TextField(loc.t("join.name"), text: $playerName)
      Button(loc.t("common.ok")) {
        guard !playerName.isEmpty else { return }
        UserDefaults.standard.set(playerName, forKey: "playerName")
        startMatch()
      }
      Button(loc.t("common.close"), role: .cancel) {}
    }
    .navigationDestination(isPresented: $navigateToGame) {
      RoomFlowView(
        leagueLevel: selectedLevel,
        playerNameForRetry: playerName
      )
        .environmentObject(svc)
        .environmentObject(loc)
        .environmentObject(progression)
        .environmentObject(leaderboard)
    }
  }

  // MARK: - Actions

  private func onLevelTapped(_ level: Int) {
    guard progression.isUnlocked(level) else { return }
    selectedLevel = level
    if playerName.isEmpty {
      showNamePrompt = true
    } else {
      startMatch()
    }
  }

  private func startMatch() {
    guard !isJoining else { return }
    isJoining = true
    let name = playerName.isEmpty ? "Player" : playerName

    progression.findAndJoinBotRoom(
      level: selectedLevel,
      playerName: name,
      svc: svc,
      loc: loc
    ) { success in
      isJoining = false
      if success {
        navigateToGame = true
      }
    }
  }
}

// MARK: - Level Card

private struct LevelCard: View {
  let level: LeagueLevel
  let isUnlocked: Bool
  let remainingTime: TimeInterval?
  let isJoining: Bool
  let loc: LocalizationManager
  let action: () -> Void

  private var gradient: LinearGradient {
    let colors: [Color] = switch level.level {
    case 1: [Color(red: 0.6, green: 0.4, blue: 0.2), Color(red: 0.7, green: 0.5, blue: 0.3)]
    case 2: [Color(red: 0.5, green: 0.5, blue: 0.6), Color(red: 0.6, green: 0.6, blue: 0.7)]
    case 3: [Color(red: 0.7, green: 0.6, blue: 0.2), Color(red: 0.8, green: 0.7, blue: 0.3)]
    case 4: [Color(red: 0.3, green: 0.5, blue: 0.8), Color(red: 0.4, green: 0.6, blue: 0.9)]
    case 5: [Color(red: 0.5, green: 0.2, blue: 0.6), Color(red: 0.6, green: 0.3, blue: 0.7)]
    case 6: [Color(red: 0.8, green: 0.15, blue: 0.15), Color(red: 0.95, green: 0.3, blue: 0.1)]
    default: [.gray, .gray]
    }
    return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        // Level emoji
        Text(level.emoji)
          .font(.system(size: 32))
          .frame(width: 52, height: 52)
          .background(
            Circle().fill(.white.opacity(isUnlocked ? 0.2 : 0.1))
          )

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(loc.t("league.level", level.level))
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundStyle(isUnlocked ? .white : .white.opacity(0.5))

            Text(levelLocalizedName)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(isUnlocked ? .white.opacity(0.8) : .white.opacity(0.4))
          }

          if isUnlocked {
            if let remaining = remainingTime {
              HStack(spacing: 4) {
                Image(systemName: "clock")
                  .font(.system(size: 10))
                Text(loc.t("league.keyExpires", Self.formatRemaining(remaining)))
                  .font(.system(size: 11))
              }
              .foregroundStyle(.orange)
            } else {
              Text(loc.t("league.readyToPlay"))
                .font(.system(size: 12))
                .foregroundStyle(.green)
            }
          } else {
            Text(loc.t("league.needKey", level.level - 1))
              .font(.system(size: 12))
              .foregroundStyle(.white.opacity(0.5))
          }
        }

        Spacer()

        if isJoining {
          ProgressView()
            .tint(.white)
        } else if isUnlocked {
          Image(systemName: "play.fill")
            .font(.system(size: 20))
            .foregroundStyle(.white.opacity(0.8))
        } else {
          Image(systemName: "lock.fill")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.4))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(gradient)
          .opacity(isUnlocked ? 1 : 0.5)
      )
      .shadow(color: isUnlocked ? .black.opacity(0.15) : .clear, radius: 6, y: 3)
    }
    .disabled(!isUnlocked || isJoining)
  }

  private var levelLocalizedName: String {
    loc.t("league.levelName.\(level.level)")
  }

  static func formatRemaining(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let days = total / 86400
    let hours = (total % 86400) / 3600
    if days > 0 {
      return "\(days)d \(hours)h"
    } else {
      let minutes = (total % 3600) / 60
      return "\(hours)h \(minutes)m"
    }
  }
}
