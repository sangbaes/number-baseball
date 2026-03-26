import FirebaseAnalytics

enum GameAnalytics {

  // MARK: - Screen Views

  static func screenView(_ name: String) {
    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
      AnalyticsParameterScreenName: name,
    ])
  }

  // MARK: - Language

  static func languageChanged(to lang: String) {
    Analytics.logEvent("language_changed", parameters: [
      "language": lang,
    ])
  }

  // MARK: - Game Mode

  static func gameModeSelected(_ mode: String) {
    Analytics.logEvent("game_mode_selected", parameters: [
      "mode": mode,
    ])
  }

  // MARK: - Room Events

  static func roomCreated(mode: String, isPublic: Bool) {
    Analytics.logEvent("room_created", parameters: [
      "game_mode": mode,
      "is_public": isPublic ? "true" : "false",
    ])
  }

  static func roomJoined(method: String) {
    Analytics.logEvent("room_joined", parameters: [
      "method": method,  // "code" or "browse"
    ])
  }

  static func roomLeft() {
    Analytics.logEvent("room_left", parameters: nil)
  }

  // MARK: - Gameplay

  static func guessSubmitted(attempt: Int) {
    Analytics.logEvent("guess_submitted", parameters: [
      "attempt_number": attempt,
    ])
  }

  static func gameWon(mode: String, attempts: Int) {
    Analytics.logEvent("game_won", parameters: [
      "mode": mode,
      "attempts": attempts,
    ])
  }

  static func gameLost(mode: String, attempts: Int) {
    Analytics.logEvent("game_lost", parameters: [
      "mode": mode,
      "attempts": attempts,
    ])
  }

  static func gameDraw(attempts: Int) {
    Analytics.logEvent("game_draw", parameters: [
      "attempts": attempts,
    ])
  }

  // MARK: - Solo

  static func soloGameStarted() {
    Analytics.logEvent("solo_game_started", parameters: nil)
  }

  static func soloGameWon(attempts: Int) {
    Analytics.logEvent("solo_game_won", parameters: [
      "attempts": attempts,
    ])
  }

  static func soloGameLost() {
    Analytics.logEvent("solo_game_lost", parameters: nil)
  }

  // MARK: - How to Play

  static func howToPlayOpened() {
    Analytics.logEvent("how_to_play_opened", parameters: nil)
  }

  // MARK: - Leaderboard

  static func leaderboardTabChanged(tab: String) {
    Analytics.logEvent("leaderboard_tab_changed", parameters: [
      "tab": tab,
    ])
  }

  static func soloScoreSubmitted(attempts: Int) {
    Analytics.logEvent("solo_score_submitted", parameters: [
      "attempts": attempts,
    ])
  }

  static func leagueLeaderboardUpdated(level: Int) {
    Analytics.logEvent("league_leaderboard_updated", parameters: [
      "level": level,
    ])
  }
}
