import SwiftUI

struct RoomFlowView: View {
  @EnvironmentObject var svc: RoomService
  @EnvironmentObject var loc: LocalizationManager
  @EnvironmentObject var progression: ProgressionManager
  @Environment(\.dismiss) private var dismiss

  @State private var secret = ""
  @State private var guess = ""
  @FocusState private var isFocused: Bool

  // League mode context (passed from LeagueHomeView; 0 = normal multiplayer)
  var leagueLevel: Int = 0
  var playerNameForRetry: String = ""

  /// Effective league level: prefer svc.level (updated per room), fall back to init value
  private var effectiveLeagueLevel: Int {
    svc.level > 0 ? svc.level : leagueLevel
  }

  // CPU player (local game logic for league mode)
  @State private var cpuPlayer = CPUPlayer()

  // League result overlay
  @State private var showLeagueResult = false
  @State private var leaguePlayerWon = false
  @State private var isProcessing = false
  @State private var keyGrantFailed = false
  @State private var leagueResultTask: Task<Void, Never>? = nil

  // Post-game overlay (일반 멀티플레이어)
  @State private var showPostGame = false
  @State private var postGameTask: Task<Void, Never>? = nil
  @State private var rematchPending = false

  // MARK: - Post-Game Actions

  private func handlePlayAgain() {
    postGameTask?.cancel()
    showPostGame = false
    rematchPending = true
    svc.requestRematch()
  }

  private func handlePostGameLeave() {
    postGameTask?.cancel()
    showPostGame = false
    rematchPending = false
    GameAnalytics.roomLeft()
    svc.leaveRoom()
  }

  // MARK: - Share Helpers

  private var roomInviteText: String {
    let base = loc.t("share.roomInvite", svc.roomCode)
    return "\(base)\n\(AppConfig.appStoreURL)"
  }

  private func multiResultShareText(out: OutcomeState) -> String {
    let attempts = myGuesses.count
    let base: String
    switch out.type {
    case "win" where out.winnerId == myId:
      base = loc.t("share.multiWin", attempts)
    case "forfeit" where out.winnerId == myId:
      base = loc.t("share.multiWin", attempts)
    case "draw":
      base = loc.t("share.multiDraw")
    default:
      base = loc.t("share.multiLose")
    }
    return "\(base)\n\(AppConfig.appStoreURL)"
  }

  private var myId: String { svc.playerId }
  private var oppId: String { myId == "p1" ? "p2" : "p1" }
  private var myName: String { svc.players[myId]?.name ?? loc.t("multi.me") }
  private var oppName: String { svc.players[oppId]?.name ?? loc.t("multi.opponent") }
  private var isPlaying: Bool { svc.status == "playing" }
  private var isFinished: Bool { svc.status == "finished" }

  private var myGuesses: [(guess: String, result: Result?)] {
    svc.rounds
      .sorted { $0.key < $1.key }
      .compactMap { entry in
        guard let g = entry.value.guessFrom[myId] else { return nil }
        return (guess: g.value, result: entry.value.resultFor[myId])
      }
  }

  private var oppGuesses: [(guess: String, result: Result?)] {
    svc.rounds
      .sorted { $0.key < $1.key }
      .compactMap { entry in
        guard let g = entry.value.guessFrom[oppId] else { return nil }
        return (guess: g.value, result: entry.value.resultFor[oppId])
      }
  }

  private var pairedRows: [(idx: Int, my: (guess: String, result: Result?)?, opp: (guess: String, result: Result?)?)] {
    if svc.gameMode == "turn" {
      let sorted = svc.rounds.sorted { $0.key < $1.key }
      guard !sorted.isEmpty else { return [] }
      return sorted.reversed().enumerated().map { _, entry in
        let (roundNum, rs) = entry
        let my: (guess: String, result: Result?)? = rs.guessFrom[myId].map {
          (guess: $0.value, result: rs.resultFor[myId])
        }
        let opp: (guess: String, result: Result?)? = rs.guessFrom[oppId].map {
          (guess: $0.value, result: rs.resultFor[oppId])
        }
        return (idx: roundNum, my: my, opp: opp)
      }
    } else {
      let maxCount = max(myGuesses.count, oppGuesses.count)
      guard maxCount > 0 else { return [] }
      return (0..<maxCount).reversed().map { i in
        let my = i < myGuesses.count ? myGuesses[i] : nil
        let opp = i < oppGuesses.count ? oppGuesses[i] : nil
        return (idx: i, my: my, opp: opp)
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      Divider()

      if !isPlaying && !isFinished {
        if svc.gameMode == "turn" {
          turnLobbySection
        } else {
          commitSection
        }
      }

      if let out = svc.outcome {
        OutcomeBanner(out: out, myId: myId, loc: loc)
          .padding(.horizontal)
          .padding(.top, 8)

        // 결과 공유 버튼 (리그 모드 제외)
        if effectiveLeagueLevel == 0 {
          ShareLink(item: multiResultShareText(out: out)) {
            Label(loc.t("share.resultButton"), systemImage: "square.and.arrow.up")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)
          }
          .padding(.bottom, 4)
        }
      }

      if isPlaying || isFinished {
        historyList
      }

    }
    .overlay {
      if showPostGame && effectiveLeagueLevel == 0, let out = svc.outcome {
        PostGameOverlay(
          out: out,
          myId: myId,
          myName: myName,
          oppName: oppName,
          myGuessCount: myGuesses.count,
          oppGuessCount: oppGuesses.count,
          shareText: multiResultShareText(out: out),
          rematchPending: rematchPending,
          loc: loc,
          onPlayAgain: handlePlayAgain,
          onLeave: handlePostGameLeave
        )
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
      }
    }
    .overlay {
      if showLeagueResult && effectiveLeagueLevel > 0 {
        LeagueResultOverlay(
          playerWon: leaguePlayerWon,
          level: effectiveLeagueLevel,
          isProcessing: isProcessing,
          keyGrantFailed: keyGrantFailed,
          loc: loc,
          onNextLevel: handleNextLevel,
          onRetry: handleRetry,
          onBackToLeague: handleBackToLeague
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
      }
    }
    .navigationTitle(loc.t("multi.title"))
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(loc.t("multi.leave"), role: .destructive) {
          postGameTask?.cancel()
          showPostGame = false
          rematchPending = false
          GameAnalytics.roomLeft()
          cpuPlayer.stop()
          svc.leaveRoom()
          if effectiveLeagueLevel > 0 {
            dismiss()
          }
        }
        .font(.subheadline)
      }
    }
    .onAppear {
      GameAnalytics.screenView("multiplayer_game")
      GameAnalytics.gameModeSelected(svc.gameMode)
      if effectiveLeagueLevel > 0 {
        cpuPlayer.start(level: effectiveLeagueLevel)
      }
    }
    .onChange(of: svc.rounds) { _, _ in
      svc.judgeOpponentIfNeeded()
    }
    .onChange(of: svc.currentTurn) { _, _ in
      if effectiveLeagueLevel > 0 {
        cpuPlayer.onRoomStateChanged(svc: svc)
      }
    }
    .onChange(of: svc.status) { _, newStatus in
      if effectiveLeagueLevel > 0 && newStatus == "playing" {
        cpuPlayer.onRoomStateChanged(svc: svc)
      }
    }
    .onChange(of: svc.outcome) { _, out in
      guard let out else { return }
      // Analytics
      switch out.type {
      case "draw":
        GameAnalytics.gameDraw(attempts: myGuesses.count)
      case "win":
        if out.winnerId == myId {
          GameAnalytics.gameWon(mode: svc.gameMode, attempts: myGuesses.count)
        } else {
          GameAnalytics.gameLost(mode: svc.gameMode, attempts: myGuesses.count)
        }
      case "forfeit":
        if out.winnerId == myId {
          GameAnalytics.gameWon(mode: svc.gameMode, attempts: myGuesses.count)
        } else {
          GameAnalytics.gameLost(mode: svc.gameMode, attempts: myGuesses.count)
        }
      default: break
      }

      // 일반 멀티플레이어: 결과 팝업
      if effectiveLeagueLevel == 0 {
        postGameTask?.cancel()
        postGameTask = Task {
          try? await Task.sleep(for: .seconds(0.9))
          guard !Task.isCancelled else { return }
          withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            showPostGame = true
          }
        }
      }

      // League mode: show inline result overlay after OutcomeBanner
      if effectiveLeagueLevel > 0 {
        leaguePlayerWon = (out.winnerId == myId)
        leagueResultTask?.cancel()
        leagueResultTask = Task {
          try? await Task.sleep(for: .seconds(1.5))
          guard !Task.isCancelled else { return }
          withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLeagueResult = true
          }
        }
      }
    }
    // p1: 양쪽 모두 동의하면 새 방 생성
    .onChange(of: svc.rematchRequests) { _, requests in
      guard rematchPending else { return }
      guard svc.playerId == "p1" else { return }
      guard requests.contains("p1") && requests.contains("p2") else { return }
      rematchPending = false
      let name = svc.playerName
      let mode = svc.gameMode
      svc.performRematchAsHost(name: name, mode: mode)
    }
    // p2: 새 방 코드가 생기면 입장
    .onChange(of: svc.rematchNewRoomCode) { _, newCode in
      guard rematchPending else { return }
      guard svc.playerId == "p2" else { return }
      guard let code = newCode else { return }
      rematchPending = false
      let name = svc.playerName
      svc.performRematchAsGuest(newCode: code, name: name)
    }
    // 상대가 떠나면 waiting 해제 + overlay 재표시
    .onChange(of: svc.players) { _, newPlayers in
      guard rematchPending else { return }
      let opp = svc.playerId == "p1" ? "p2" : "p1"
      guard newPlayers[opp] == nil else { return }
      rematchPending = false
      withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
        showPostGame = true
      }
    }
  }

  // MARK: - League Result Actions

  private func resetOverlayState() {
    showLeagueResult = false
    leaguePlayerWon = false
    isProcessing = false
    keyGrantFailed = false
    leagueResultTask?.cancel()
    leagueResultTask = nil
  }

  private func handleNextLevel() {
    let level = effectiveLeagueLevel
    guard level < ProgressionManager.levels.count else { return }
    isProcessing = true
    keyGrantFailed = false

    let nextLevel = level + 1
    print("[LEAGUE] handleNextLevel: effectiveLevel=\(level), leagueLevel=\(leagueLevel), svc.level=\(svc.level), nextLevel=\(nextLevel)")

    Task {
      let roomCode = svc.roomCode
      let success = await progression.grantKey(
        level: level,
        roomCode: roomCode
      )

      if !success {
        isProcessing = false
        keyGrantFailed = true
        return
      }

      // Leave current room & reset UI
      cpuPlayer.stop()
      svc.leaveRoom()
      resetOverlayState()
      print("[LEAGUE] handleNextLevel: left room, now finding level \(nextLevel)")

      // Create next room
      let name = playerNameForRetry
      progression.findAndJoinBotRoom(
        level: nextLevel,
        playerName: name,
        svc: svc,
        loc: loc
      ) { success in
        isProcessing = false
        if success {
          cpuPlayer.start(level: nextLevel)
        } else {
          dismiss()
        }
      }
    }
  }

  private func handleRetry() {
    isProcessing = true
    let currentLevel = effectiveLeagueLevel
    let name = playerNameForRetry
    let roomCode = svc.roomCode

    // Record loss
    progression.recordLoss(level: currentLevel, roomCode: roomCode)

    // Leave current room & reset UI
    cpuPlayer.stop()
    svc.leaveRoom()
    resetOverlayState()

    // Create new room at same level
    progression.findAndJoinBotRoom(
      level: currentLevel,
      playerName: name,
      svc: svc,
      loc: loc
    ) { success in
      isProcessing = false
      if success {
        cpuPlayer.start(level: currentLevel)
      } else {
        dismiss()
      }
    }
  }

  private func handleBackToLeague() {
    let level = effectiveLeagueLevel
    // Record loss if applicable
    if !leaguePlayerWon {
      progression.recordLoss(level: level, roomCode: svc.roomCode)
    }

    // Grant key for win before leaving (if not already granted)
    if leaguePlayerWon {
      let roomCode = svc.roomCode
      Task {
        _ = await progression.grantKey(level: level, roomCode: roomCode)
      }
    }

    // Leave room
    cpuPlayer.stop()
    if svc.status != "idle" {
      svc.leaveRoom()
    }

    showLeagueResult = false
    dismiss()
  }

  // MARK: - Header Bar

  private var headerBar: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        Image(systemName: "number")
          .foregroundStyle(.secondary)
        Text(svc.roomCode)
          .font(.system(size: 14, weight: .bold, design: .monospaced))
        // 로비(상대 대기 중)일 때만 공유 아이콘 표시
        if !isPlaying && !isFinished {
          ShareLink(item: roomInviteText) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(Color.accentColor)
          }
        }
      }

      Text(svc.gameMode == "turn" ? loc.t("multi.turnMode") : loc.t("multi.simMode"))
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12))
        .clipShape(Capsule())

      if svc.isPublic && !svc.groupCode.isEmpty {
        HStack(spacing: 4) {
          Image(systemName: "person.3")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
          Text(svc.groupCode)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.12))
        .clipShape(Capsule())
      }

      Spacer()

      HStack(spacing: 8) {
        playerChip(name: myName, connected: svc.players[myId]?.connected ?? false, isMe: true)
        Text("vs")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
        playerChip(name: oppName, connected: svc.players[oppId]?.connected ?? false, isMe: false)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  private func playerChip(name: String, connected: Bool, isMe: Bool) -> some View {
    HStack(spacing: 3) {
      Circle()
        .fill(connected ? .green : .red)
        .frame(width: 6, height: 6)
      Text(name)
        .font(.system(size: 13, weight: isMe ? .bold : .regular))
        .lineLimit(1)
    }
  }

  // MARK: - Group Code Display

  private var groupCodeDisplay: some View {
    VStack(spacing: 4) {
      Text(loc.t("multi.shareGroupCode"))
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(spacing: 8) {
        Text(svc.groupCode)
          .font(.system(size: 28, weight: .bold, design: .monospaced))
        Button {
          UIPasteboard.general.string = svc.groupCode
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 16))
        }
      }
    }
    .padding(.bottom, 4)
  }

  // MARK: - Commit Section

  private var commitSection: some View {
    VStack(spacing: 10) {
      if svc.isPublic && !svc.groupCode.isEmpty {
        groupCodeDisplay
      }

      // 친구 초대 카드 (리그 모드 제외)
      if effectiveLeagueLevel == 0 {
        ShareLink(item: roomInviteText) {
          HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 14, weight: .semibold))
            Text(loc.t("share.inviteButton"))
              .font(.system(size: 14, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.accentColor.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
          )
        }
        .foregroundStyle(Color.accentColor)
      }

      Text(loc.t("multi.commitSection"))
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        TextField(loc.t("multi.commitPlaceholder"), text: $secret)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .multilineTextAlignment(.center)
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .frame(width: 100)
          .padding(.vertical, 8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .onChange(of: secret) { _, nv in
            secret = BaseballLogic.filterUniqueDigits(nv)
          }

        Button(loc.t("multi.commitButton")) { svc.commitMySecret(secret) }
          .buttonStyle(.borderedProminent)
          .disabled(secret.count != 3)
      }

      HStack(spacing: 16) {
        Label(
          svc.commits.contains(myId) ? loc.t("multi.committed") : loc.t("multi.waiting"),
          systemImage: svc.commits.contains(myId) ? "checkmark.circle.fill" : "clock"
        )
        .foregroundStyle(svc.commits.contains(myId) ? .green : .secondary)

        Label(
          svc.commits.contains(oppId) ? loc.t("multi.committed") : loc.t("multi.waiting"),
          systemImage: svc.commits.contains(oppId) ? "checkmark.circle.fill" : "clock"
        )
        .foregroundStyle(svc.commits.contains(oppId) ? .green : .secondary)
      }
      .font(.caption)
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  // MARK: - Turn Lobby

  private var turnLobbySection: some View {
    VStack(spacing: 14) {
      if svc.isPublic && !svc.groupCode.isEmpty {
        groupCodeDisplay
      }

      // 친구 초대 카드 (리그 모드 제외)
      if effectiveLeagueLevel == 0 {
        ShareLink(item: roomInviteText) {
          HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 14, weight: .semibold))
            Text(loc.t("share.inviteButton"))
              .font(.system(size: 14, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.accentColor.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
          )
        }
        .foregroundStyle(Color.accentColor)
      }

      Image(systemName: "person.2.fill")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)

      Text(loc.t("multi.waitingOpponent"))
        .font(.headline)

      Text(loc.t("multi.turnLobbyDesc"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      HStack(spacing: 16) {
        Label(
          svc.players[myId] != nil ? loc.t("multi.joined") : loc.t("multi.waiting"),
          systemImage: svc.players[myId] != nil ? "checkmark.circle.fill" : "clock"
        )
        .foregroundStyle(svc.players[myId] != nil ? .green : .secondary)

        Label(
          svc.players[oppId] != nil ? loc.t("multi.joined") : loc.t("multi.waiting"),
          systemImage: svc.players[oppId] != nil ? "checkmark.circle.fill" : "clock"
        )
        .foregroundStyle(svc.players[oppId] != nil ? .green : .secondary)
      }
      .font(.caption)
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  // MARK: - History List

  private var historyList: some View {
    List {
      HStack(spacing: 0) {
        Text("\(myName) (\(myGuesses.count))")
          .font(.system(size: 11, weight: .bold))
          .frame(maxWidth: .infinity)
        Text("R")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.tertiary)
          .frame(width: 24)
        Text("\(oppName) (\(oppGuesses.count))")
          .font(.system(size: 11, weight: .bold))
          .frame(maxWidth: .infinity)
      }
      .foregroundStyle(.secondary)
      .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
      .listRowBackground(Color.clear)

      if pairedRows.isEmpty {
        Text(loc.t("multi.emptyHistory"))
          .foregroundStyle(.tertiary)
          .font(.subheadline)
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
      } else {
        ForEach(pairedRows, id: \.idx) { row in
          let displayNum = svc.gameMode == "turn" ? row.idx : row.idx + 1
          pairedGuessRow(number: displayNum, my: row.my, opp: row.opp)
        }
      }
    }
    .listStyle(.plain)
    .safeAreaInset(edge: .bottom) {
      if isPlaying {
        inputBar
      }
    }
  }

  private func pairedGuessRow(
    number: Int,
    my: (guess: String, result: Result?)?,
    opp: (guess: String, result: Result?)?
  ) -> some View {
    HStack(spacing: 0) {
      if let m = my {
        HStack(spacing: 4) {
          Text(m.guess)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .monospacedDigit()
          resultBadge(m.result)
        }
        .frame(maxWidth: .infinity)
      } else {
        Text("—")
          .foregroundStyle(.quaternary)
          .frame(maxWidth: .infinity)
      }

      Text("\(number)")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.tertiary)
        .frame(width: 24)

      if let o = opp {
        HStack(spacing: 4) {
          resultBadge(o.result)
          Text(o.guess)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
      } else {
        Text("—")
          .foregroundStyle(.quaternary)
          .frame(maxWidth: .infinity)
      }
    }
    .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
  }

  // MARK: - Result Badge

  private func resultBadge(_ res: Result?) -> some View {
    Text(formatRes(res))
      .font(.system(size: 14, weight: .semibold, design: .rounded))
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(resultColor(res))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func resultColor(_ res: Result?) -> Color {
    guard let r = res else { return .gray.opacity(0.1) }
    if r.strike == 3 { return .green.opacity(0.2) }
    if r.strike > 0  { return .orange.opacity(0.15) }
    if r.ball > 0    { return .blue.opacity(0.1) }
    return .gray.opacity(0.1)
  }

  private func formatRes(_ r: Result?) -> String {
    guard let r else { return "···" }
    if r.strike == 0 && r.ball == 0 { return "OUT" }
    var parts: [String] = []
    if r.strike > 0 { parts.append("\(r.strike)S") }
    if r.ball > 0 { parts.append("\(r.ball)B") }
    return parts.joined(separator: " ")
  }

  // MARK: - Input Bar

  private func doSubmit() {
    let g = guess
    guard !g.isEmpty else { return }
    svc.submitGuess(g)
    GameAnalytics.guessSubmitted(attempt: myGuesses.count + 1)
    guess = ""
  }

  private var isMyTurn: Bool {
    svc.gameMode != "turn" || svc.currentTurn == myId
  }

  private var inputBar: some View {
    HStack(spacing: 10) {
      Text("\(myGuesses.count)\(loc.t("multi.attempts"))")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.secondary)

      if svc.gameMode == "turn" && !isMyTurn {
        Text(loc.t("multi.opponentTurn"))
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity)
      } else {
        TextField(loc.t("multi.guessPlaceholder"), text: $guess)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .frame(width: 90)
          .padding(.vertical, 8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .focused($isFocused)
          .onChange(of: guess) { _, nv in
            guess = BaseballLogic.filterUniqueDigits(nv)
          }
          .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
              Text("\(myGuesses.count)\(loc.t("multi.attempts"))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

              Spacer()

              Button { doSubmit() } label: {
                Text(loc.t("multi.submit"))
                  .font(.system(size: 16, weight: .bold))
                  .padding(.horizontal, 20)
                  .padding(.vertical, 6)
              }
              .buttonStyle(.borderedProminent)
              .disabled(!canSubmit)
            }
          }
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 10)
    .background(.bar)
  }

  private var canSubmit: Bool {
    guard svc.status == "playing" else { return false }
    guard guess.count == 3 else { return false }
    if svc.gameMode == "turn", let t = svc.currentTurn, t != myId { return false }
    return true
  }
}

// MARK: - Outcome Banner

private struct OutcomeBanner: View {
  let out: OutcomeState
  let myId: String
  let loc: LocalizationManager

  var body: some View {
    let text: String = {
      switch out.type {
      case "draw":
        return "\u{1F91D} \(loc.t("multi.draw"))"
      case "win":
        return out.winnerId == myId ? "\u{1F389} \(loc.t("multi.win"))" : "\u{1F622} \(loc.t("multi.lose"))"
      case "forfeit":
        if out.reason == "hash_mismatch" {
          return out.winnerId == myId ? "\u{1F6E1}\u{FE0F} \(loc.t("multi.winCheat"))" : "\u{1F6AB} \(loc.t("multi.loseCheat"))"
        }
        return out.winnerId == myId ? "\u{1F3C6} \(loc.t("multi.winDisconnect"))" : "\u{1F6AA} \(loc.t("multi.loseDisconnect"))"
      default:
        return loc.t("multi.result", out.type)
      }
    }()

    Text(text)
      .font(.system(size: 14, weight: .bold))
      .frame(maxWidth: .infinity)
      .padding(10)
      .background(.thinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - League Result Overlay

private struct LeagueResultOverlay: View {
  let playerWon: Bool
  let level: Int
  let isProcessing: Bool
  let keyGrantFailed: Bool
  let loc: LocalizationManager
  let onNextLevel: () -> Void
  let onRetry: () -> Void
  let onBackToLeague: () -> Void

  private var nextLevel: Int { level + 1 }
  /// Regular levels 1~5: next level button
  private var hasNextRegularLevel: Bool { level < 5 }
  /// Level 5 cleared: bonus level available
  private var hasBonusLevel: Bool { level == 5 }
  /// Level 6 (bonus) cleared
  private var isBonusCleared: Bool { level >= 6 }

  var body: some View {
    ZStack {
      // Dimmed background
      Color.black.opacity(0.5)
        .ignoresSafeArea()

      VStack(spacing: 20) {
        // Emoji
        Text(playerWon ? (isBonusCleared ? "\u{1F525}" : "\u{1F3C6}") : "\u{1F624}")
          .font(.system(size: 64))

        // Title
        Text(playerWon ? loc.t("match.win") : loc.t("match.lose"))
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .foregroundStyle(playerWon ? .green : .red)

        // Key earned info (levels 1~4 win)
        if playerWon && hasNextRegularLevel {
          HStack(spacing: 8) {
            Image(systemName: "key.fill")
              .font(.system(size: 20))
              .foregroundStyle(.yellow)
            Text(loc.t("match.keyEarned", nextLevel))
              .font(.system(size: 16, weight: .bold, design: .rounded))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 14)
              .fill(.yellow.opacity(0.15))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
          )
        }

        // Level 5 win: all cleared + bonus teaser
        if playerWon && hasBonusLevel {
          VStack(spacing: 8) {
            Text(loc.t("match.allCleared"))
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.purple)
            Text(loc.t("bonus.unlocked"))
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }
        }

        // Level 6 (bonus) win
        if playerWon && isBonusCleared {
          Text(loc.t("bonus.cleared"))
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(
              LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
            )
        }

        if keyGrantFailed {
          Text(loc.t("league.noBots"))
            .font(.caption)
            .foregroundStyle(.red)
        }

        Spacer().frame(height: 10)

        // Action buttons
        if playerWon {
          // Regular next level (1~4 → 2~5)
          if hasNextRegularLevel {
            Button(action: onNextLevel) {
              HStack {
                if isProcessing {
                  ProgressView().tint(.white)
                }
                Text(loc.t("match.nextLevel", nextLevel))
              }
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(RoundedRectangle(cornerRadius: 14).fill(.green))
            }
            .disabled(isProcessing)
          }

          // Bonus level entry (level 5 win only)
          if hasBonusLevel {
            Button(action: onNextLevel) {
              HStack(spacing: 8) {
                if isProcessing {
                  ProgressView().tint(.white)
                }
                Text("\u{1F525}")
                Text(loc.t("bonus.challenge"))
              }
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(
                RoundedRectangle(cornerRadius: 14).fill(
                  LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
              )
            }
            .disabled(isProcessing)
          }

          Button(action: onBackToLeague) {
            Text(loc.t("match.backToLeague"))
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
          }
          .disabled(isProcessing)
        } else {
          // Loss buttons
          Button(action: onRetry) {
            HStack {
              if isProcessing {
                ProgressView().tint(.white)
              }
              Text(loc.t("match.retry"))
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
          }
          .disabled(isProcessing)

          Button(action: onBackToLeague) {
            Text(loc.t("match.backToLeague"))
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
          }
          .disabled(isProcessing)
        }
      }
      .padding(28)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(.regularMaterial)
      )
      .padding(.horizontal, 32)
    }
  }
}

// MARK: - Post Game Overlay

private struct PostGameOverlay: View {
  let out: OutcomeState
  let myId: String
  let myName: String
  let oppName: String
  let myGuessCount: Int
  let oppGuessCount: Int
  let shareText: String
  let rematchPending: Bool
  let loc: LocalizationManager
  let onPlayAgain: () -> Void
  let onLeave: () -> Void

  private var isWin: Bool {
    (out.type == "win" || out.type == "forfeit") && out.winnerId == myId
  }
  private var isDraw: Bool { out.type == "draw" }

  var body: some View {
    ZStack {
      Color.black.opacity(0.55)
        .ignoresSafeArea()

      VStack(spacing: 0) {

        // ── 결과 이모지 ──
        Text(resultEmoji)
          .font(.system(size: 72))
          .padding(.bottom, 8)

        // ── 결과 제목 ──
        Text(resultTitle)
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .foregroundStyle(resultColor)
          .padding(.bottom, 24)

        // ── 시도 횟수 카드 ──
        HStack(spacing: 16) {
          attemptBox(name: myName, count: myGuessCount, highlight: true)
          Text("vs")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.tertiary)
          attemptBox(name: oppName, count: oppGuessCount, highlight: false)
        }
        .padding(.bottom, 20)

        // ── 결과 공유 버튼 ──
        ShareLink(item: shareText) {
          Label(loc.t("share.resultButton"), systemImage: "square.and.arrow.up")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 22)

        // ── 액션 버튼 ──
        VStack(spacing: 10) {
          if rematchPending {
            // 상대방 동의 대기 중
            HStack(spacing: 8) {
              ProgressView()
                .tint(.secondary)
              Text(loc.t("postgame.waiting"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
              RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray5))
            )
          } else {
            Button(action: onPlayAgain) {
              Text(loc.t("postgame.oneMore"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                  RoundedRectangle(cornerRadius: 14)
                    .fill(isWin ? Color.green : isDraw ? Color.orange : Color.blue)
                )
            }
          }

          Button(action: onLeave) {
            Text(loc.t("postgame.leave"))
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
              .background(
                RoundedRectangle(cornerRadius: 14)
                  .fill(.ultraThinMaterial)
              )
          }
        }
      }
      .padding(28)
      .background(
        RoundedRectangle(cornerRadius: 26)
          .fill(.regularMaterial)
      )
      .padding(.horizontal, 28)
    }
  }

  // MARK: Attempt Box

  private func attemptBox(name: String, count: Int, highlight: Bool) -> some View {
    VStack(spacing: 4) {
      // 숫자만 크게
      Text("\(count)")
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .foregroundStyle(highlight ? Color.accentColor : Color.primary)
        .monospacedDigit()
      // "회" / "attempts" 작게
      Text(loc.t("multi.attempts").trimmingCharacters(in: .whitespaces))
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
      // 플레이어 이름
      Text(name)
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
    .frame(minWidth: 100)
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  // MARK: Computed

  private var resultEmoji: String {
    if isDraw { return "🤝" }
    if isWin { return out.reason == "disconnect" ? "🚪" : "🏆" }
    return "🥲"
  }

  private var resultTitle: String {
    switch out.type {
    case "draw":
      return loc.t("multi.draw")
    case "win":
      return out.winnerId == myId ? loc.t("multi.win") : loc.t("multi.lose")
    case "forfeit":
      if out.reason == "hash_mismatch" {
        return out.winnerId == myId ? loc.t("multi.winCheat") : loc.t("multi.loseCheat")
      }
      return out.winnerId == myId ? loc.t("multi.winDisconnect") : loc.t("multi.loseDisconnect")
    default:
      return loc.t("multi.result", out.type)
    }
  }

  private var resultColor: Color {
    if isDraw { return .orange }
    return isWin ? .green : .red
  }
}

