import SwiftUI
import FirebaseAuth

// MARK: - Leaderboard Tab Enum

enum LeaderboardTab: String, CaseIterable {
    case solo
    case league
}

// MARK: - Main Leaderboard View

struct LeaderboardView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var leaderboard: LeaderboardService

    @State private var selectedTab: LeaderboardTab = .solo

    var body: some View {
        VStack(spacing: 0) {
            Picker(loc.t("leaderboard.title"), selection: $selectedTab) {
                Text(loc.t("leaderboard.solo")).tag(LeaderboardTab.solo)
                Text(loc.t("leaderboard.league")).tag(LeaderboardTab.league)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            switch selectedTab {
            case .solo:
                SoloLeaderboardTab()
                    .environmentObject(leaderboard)
                    .environmentObject(loc)
            case .league:
                LeagueLeaderboardTab()
                    .environmentObject(leaderboard)
                    .environmentObject(loc)
            }
        }
        .navigationTitle(loc.t("leaderboard.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            GameAnalytics.screenView("leaderboard")
            leaderboard.fetchSoloLeaderboard()
            leaderboard.fetchLeagueLeaderboard()
        }
        .onChange(of: selectedTab) { tab in
            GameAnalytics.leaderboardTabChanged(tab: tab.rawValue)
        }
    }
}

// MARK: - Solo Leaderboard Tab

private struct SoloLeaderboardTab: View {
    @EnvironmentObject var leaderboard: LeaderboardService
    @EnvironmentObject var loc: LocalizationManager

    private var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        Group {
            if leaderboard.isLoading && leaderboard.soloEntries.isEmpty {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if leaderboard.soloEntries.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎯")
                .font(.system(size: 48))
            Text(loc.t("leaderboard.noScores"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(loc.t("leaderboard.soloHint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(Array(leaderboard.soloEntries.enumerated()), id: \.element.id) { idx, entry in
                SoloRow(
                    rank: idx + 1,
                    entry: entry,
                    isMe: entry.uid == currentUID,
                    loc: loc
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            }
        }
        .listStyle(.plain)
        .refreshable {
            leaderboard.fetchSoloLeaderboard()
        }
    }
}

// MARK: - League Leaderboard Tab

private struct LeagueLeaderboardTab: View {
    @EnvironmentObject var leaderboard: LeaderboardService
    @EnvironmentObject var loc: LocalizationManager

    private var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        Group {
            if leaderboard.isLoading && leaderboard.leagueEntries.isEmpty {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if leaderboard.leagueEntries.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🏆")
                .font(.system(size: 48))
            Text(loc.t("leaderboard.noScores"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(loc.t("leaderboard.leagueHint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(Array(leaderboard.leagueEntries.enumerated()), id: \.element.uid) { idx, entry in
                LeagueRow(
                    rank: idx + 1,
                    entry: entry,
                    isMe: entry.uid == currentUID,
                    loc: loc
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            }
        }
        .listStyle(.plain)
        .refreshable {
            leaderboard.fetchLeagueLeaderboard()
        }
    }
}

// MARK: - Solo Row

private struct SoloRow: View {
    let rank: Int
    let entry: SoloLeaderboardEntry
    let isMe: Bool
    let loc: LocalizationManager

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            rankBadge

            // Player name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.system(size: 15, weight: isMe ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                    if isMe {
                        Text(loc.t("leaderboard.me"))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(formatDate(entry.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Attempts badge
            Text(loc.t("leaderboard.attempts", entry.attempts))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(attemptColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(attemptColor)
        }
        .padding(.vertical, 2)
        .background(isMe ? Color.accentColor.opacity(0.05) : .clear)
    }

    private var attemptColor: Color {
        switch entry.attempts {
        case 1...3: return .green
        case 4...5: return .blue
        default: return .orange
        }
    }

    private var rankBadge: some View {
        Group {
            switch rank {
            case 1:
                Text("🥇")
                    .font(.system(size: 24))
                    .frame(width: 36)
            case 2:
                Text("🥈")
                    .font(.system(size: 24))
                    .frame(width: 36)
            case 3:
                Text("🥉")
                    .font(.system(size: 24))
                    .frame(width: 36)
            default:
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
            }
        }
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - League Row

private struct LeagueRow: View {
    let rank: Int
    let entry: LeagueLeaderboardEntry
    let isMe: Bool
    let loc: LocalizationManager

    private var levelEmoji: String {
        ProgressionManager.levels
            .first(where: { $0.level == entry.highestLevel })?.emoji ?? "⭐"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            rankBadge

            // Level emoji
            Text(levelEmoji)
                .font(.system(size: 24))
                .frame(width: 32)

            // Player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.system(size: 15, weight: isMe ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                    if isMe {
                        Text(loc.t("leaderboard.me"))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                HStack(spacing: 4) {
                    Text(loc.t("leaderboard.totalWins", entry.totalWins))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if let hours = entry.clearHours {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Text(formatClearTime(hours))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Highest level badge
            Text(loc.t("leaderboard.levelBadge", entry.highestLevel))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(levelColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(levelColor)
        }
        .padding(.vertical, 2)
        .background(isMe ? Color.accentColor.opacity(0.05) : .clear)
    }

    private var levelColor: Color {
        switch entry.highestLevel {
        case 5...: return .purple
        case 4: return .blue
        case 3: return .orange
        case 2: return .gray
        default: return .brown
        }
    }

    private var rankBadge: some View {
        Group {
            switch rank {
            case 1:
                Text("🥇")
                    .font(.system(size: 24))
                    .frame(width: 36)
            case 2:
                Text("🥈")
                    .font(.system(size: 24))
                    .frame(width: 36)
            case 3:
                Text("🥉")
                    .font(.system(size: 24))
                    .frame(width: 36)
            default:
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
            }
        }
    }

    /// Format clear duration: "Clear in 3.5h", "Clear in 2d 5h", "Clear in 45m"
    private func formatClearTime(_ hours: Double) -> String {
        if hours >= 24 {
            let days = Int(hours / 24)
            let h = Int(hours.truncatingRemainder(dividingBy: 24))
            return "Clear in \(days)d \(h)h"
        } else if hours >= 1 {
            let formatted = String(format: "%.1f", hours)
                .replacingOccurrences(of: ".0", with: "")
            return "Clear in \(formatted)h"
        } else {
            let minutes = max(1, Int(hours * 60))
            return "Clear in \(minutes)m"
        }
    }
}
