import SwiftUI
import FirebaseDatabase

// MARK: - Main Menu

struct MainMenuView: View {
  @StateObject private var svc = RoomService()
  @StateObject private var progression = ProgressionManager()
  @StateObject private var leaderboard = LeaderboardService()
  @EnvironmentObject var loc: LocalizationManager
  @State private var showHowToPlay = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {

          // ── Top Bar: Language Toggle + How to Play ──
          HStack {
            Spacer()

            Button {
              showHowToPlay = true
              GameAnalytics.howToPlayOpened()
            } label: {
              Image(systemName: "questionmark.circle")
                .font(.system(size: 20))
                .padding(8)
                .background(
                  RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                )
            }

            Menu {
              ForEach(AppLanguage.allCases, id: \.self) { lang in
                Button {
                  loc.language = lang
                  GameAnalytics.languageChanged(to: lang.rawValue)
                } label: {
                  HStack {
                    Text("\(lang.flag) \(lang.displayName)")
                    if loc.language == lang {
                      Image(systemName: "checkmark")
                    }
                  }
                }
              }
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "globe")
                  .font(.system(size: 16))
                Text(loc.language.flag)
                  .font(.system(size: 18))
              }
              .padding(8)
              .background(
                RoundedRectangle(cornerRadius: 10)
                  .fill(.ultraThinMaterial)
              )
            }
          }
          .padding(.horizontal)
          .padding(.top, 8)

          // ── Title ──
          VStack(spacing: 6) {
            Text("⚾")
              .font(.system(size: 52))
            Text(loc.t("app.title"))
              .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(loc.t("app.subtitle"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 20)
          .padding(.bottom, 28)

          // ── CPU League: Hero Card ──
          VStack(spacing: 14) {
            NavigationLink {
              LeagueHomeView()
                .environmentObject(progression)
                .environmentObject(svc)
                .environmentObject(loc)
                .environmentObject(leaderboard)
            } label: {
              CPUBattleCard(
                title: loc.t("league.title"),
                desc: loc.t("league.desc"),
                badge: loc.t("league.badge")
              )
            }

            // ── Friends Section ──
            HStack(spacing: 12) {
              NavigationLink {
                CreateRoomView().environmentObject(svc).environmentObject(loc)
              } label: {
                MenuCard(
                  icon: "👥",
                  title: loc.t("menu.createRoom"),
                  desc: loc.t("menu.createRoom.desc")
                )
              }

              NavigationLink {
                JoinRoomView().environmentObject(svc).environmentObject(loc)
              } label: {
                MenuCard(
                  icon: "🚪",
                  title: loc.t("menu.joinRoom"),
                  desc: loc.t("menu.joinRoom.desc")
                )
              }
            }

            // ── Solo Play ──
            NavigationLink {
              SoloGameView()
                .environmentObject(loc)
                .environmentObject(leaderboard)
            } label: {
              MenuCard(
                icon: "🎯",
                title: loc.t("menu.solo"),
                desc: loc.t("menu.solo.desc")
              )
            }

            // ── Leaderboard ──
            NavigationLink {
              LeaderboardView()
                .environmentObject(loc)
                .environmentObject(leaderboard)
            } label: {
              MenuCard(
                icon: "🏅",
                title: loc.t("leaderboard.title"),
                desc: loc.t("leaderboard.desc")
              )
            }
          }
          .padding(.horizontal, 20)

          // ── Footer ──
          if let url = URL(string: AppConfig.appStoreURL) {
            Link(loc.t("footer.company"), destination: url)
              .font(.system(size: 12, weight: .regular))
              .foregroundStyle(.tertiary)
              .padding(.top, 24)
              .padding(.bottom, 16)
          }
        }
      }
      .onAppear {
        svc.loc = loc
        svc.startServerOffsetListener()
        GameAnalytics.screenView("main_menu")
        progression.syncFromFirebase()
      }
      .onChange(of: loc.language) { _ in svc.loc = loc }
      .sheet(isPresented: $showHowToPlay) {
        HowToPlayView(loc: loc)
      }
      .navigationDestination(isPresented: Binding(
        get: { svc.status != "idle" && !svc.roomCode.isEmpty && svc.level == 0 },
        set: { _ in }
      )) {
        RoomFlowView().environmentObject(svc).environmentObject(loc).environmentObject(progression).environmentObject(leaderboard)
      }
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.91, green: 0.87, blue: 0.98),  // soft lavender
            Color(red: 0.85, green: 0.90, blue: 0.98),  // pastel blue
            Color(red: 0.93, green: 0.88, blue: 0.96)   // light lilac
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
      )
      .alert(loc.t("common.error"), isPresented: Binding(
        get: { svc.errorMessage != nil },
        set: { if !$0 { svc.errorMessage = nil } }
      )) {
        Button(loc.t("common.ok"), role: .cancel) {}
      } message: {
        Text(svc.errorMessage ?? "")
      }
    }
  }

}

// MARK: - CPU Battle Card (Hero)

private struct CPUBattleCard: View {
  let title: String
  let desc: String
  let badge: String

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [.purple, .blue],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 56, height: 56)
        Text("🏆")
          .font(.system(size: 28))
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text(badge)
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.25))
            .clipShape(Capsule())
            .foregroundStyle(.white)
        }
        Text(desc)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.8))
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.white.opacity(0.6))
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 18)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.35, green: 0.15, blue: 0.75),
              Color(red: 0.15, green: 0.35, blue: 0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .shadow(color: .purple.opacity(0.3), radius: 10, y: 4)
  }
}

// MARK: - Menu Card Component

private struct MenuCard: View {
  let icon: String
  let title: String
  let desc: String

  var body: some View {
    VStack(spacing: 8) {
      Text(icon)
        .font(.system(size: 32))
      Text(title)
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      Text(desc)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
  }
}

// MARK: - How to Play

private struct HowToPlayView: View {
  let loc: LocalizationManager
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {

          // Goal
          sectionBlock(
            icon: "🎯",
            title: loc.t("help.goal"),
            content: {
              Text(loc.t("help.goalDesc"))
                .font(.subheadline)
            }
          )

          // Feedback
          sectionBlock(
            icon: "💡",
            title: loc.t("help.feedback"),
            content: {
              VStack(alignment: .leading, spacing: 8) {
                feedbackRow(badge: "S", color: .green, text: loc.t("help.strikeDesc"))
                feedbackRow(badge: "B", color: .blue, text: loc.t("help.ballDesc"))
                feedbackRow(badge: "0", color: .gray, text: loc.t("help.outDesc"))
              }
            }
          )

          // Rules
          sectionBlock(
            icon: "📋",
            title: loc.t("help.rules"),
            content: {
              VStack(alignment: .leading, spacing: 6) {
                ruleRow(num: "1", text: loc.t("help.rule1"))
                ruleRow(num: "2", text: loc.t("help.rule2"))
                ruleRow(num: "3", text: loc.t("help.rule3"))
              }
            }
          )

          // Example
          sectionBlock(
            icon: "🧩",
            title: loc.t("help.example"),
            content: {
              VStack(alignment: .leading, spacing: 8) {
                Text(loc.t("help.exampleTitle"))
                  .font(.system(size: 16, weight: .bold, design: .monospaced))
                  .foregroundStyle(Color.accentColor)

                Divider()

                exampleRow(text: loc.t("help.ex1"), highlight: .gray)
                exampleRow(text: loc.t("help.ex2"), highlight: .blue)
                exampleRow(text: loc.t("help.ex3"), highlight: .blue)
                exampleRow(text: loc.t("help.ex4"), highlight: .orange)
                exampleRow(text: loc.t("help.ex5"), highlight: .orange)
                exampleRow(text: loc.t("help.ex6"), highlight: .green)
              }
            }
          )
        }
        .padding()
      }
      .navigationTitle(loc.t("help.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(loc.t("common.close")) { dismiss() }
        }
      }
    }
  }

  // MARK: Helpers

  private func sectionBlock<Content: View>(
    icon: String,
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Text(icon)
          .font(.system(size: 20))
        Text(title)
          .font(.system(size: 18, weight: .bold, design: .rounded))
      }
      content()
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }

  private func feedbackRow(badge: String, color: Color, text: String) -> some View {
    HStack(spacing: 10) {
      Text(badge)
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .frame(width: 30, height: 30)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      Text(text)
        .font(.system(size: 14))
    }
  }

  private func ruleRow(num: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text(num)
        .font(.system(size: 12, weight: .bold))
        .frame(width: 20, height: 20)
        .background(Color.accentColor.opacity(0.12))
        .clipShape(Circle())
      Text(text)
        .font(.system(size: 14))
    }
  }

  private func exampleRow(text: String, highlight: Color) -> some View {
    HStack(spacing: 8) {
      Circle()
        .fill(highlight.opacity(0.5))
        .frame(width: 8, height: 8)
      Text(text)
        .font(.system(size: 14, design: .monospaced))
    }
  }
}
