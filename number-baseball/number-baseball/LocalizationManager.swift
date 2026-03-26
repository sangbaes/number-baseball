import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable {
  case en = "en"
  case ko = "ko"
  case ja = "ja"
  case es = "es"

  var displayName: String {
    switch self {
    case .en: return "English"
    case .ko: return "한국어"
    case .ja: return "日本語"
    case .es: return "Español"
    }
  }

  var flag: String {
    switch self {
    case .en: return "🇺🇸"
    case .ko: return "🇰🇷"
    case .ja: return "🇯🇵"
    case .es: return "🇪🇸"
    }
  }
}

@MainActor
final class LocalizationManager: ObservableObject {
  @Published var language: AppLanguage {
    didSet {
      UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }
  }

  init() {
    let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    self.language = AppLanguage(rawValue: saved) ?? .en
  }

  // MARK: - String Access
  func t(_ key: String) -> String {
    strings[key] ?? key
  }

  func t(_ key: String, _ args: CVarArg...) -> String {
    let format = strings[key] ?? key
    return String(format: format, arguments: args)
  }

  private var strings: [String: String] {
    switch language {
    case .en: return Self.en
    case .ko: return Self.ko
    case .ja: return Self.ja
    case .es: return Self.es
    }
  }

  // MARK: - English Strings
  private static let en: [String: String] = [
    // Main Menu
    "app.title": "Number Baseball",
    "app.subtitle": "Number Baseball",
    "menu.createRoom": "Create Room",
    "menu.createRoom.desc": "Invite your friends",
    "menu.joinRoom": "Join Room",
    "menu.joinRoom.desc": "Join with code",
    "menu.aiBattle": "CPU Battle",
    "menu.aiBattle.desc": "Challenge CPU opponents",
    "menu.aiBattle.badge": "CPU",
    "menu.friends": "Play with Friends",
    "menu.friends.desc": "Create or join a room",
    "menu.solo": "Solo Play",
    "menu.solo.desc": "Practice alone",
    "common.error": "Error",
    "common.ok": "OK",
    "common.close": "Close",

    // Solo Game
    "solo.title": "Solo Play",
    "solo.guess": "Guess",
    "solo.newGame": "New Game",
    "solo.showAnswer": "Show Answer",
    "solo.answer": "Answer: %@",
    "solo.emptyHint": "Enter a 3-digit number (no duplicates)",
    "solo.alert": "Notice",
    "solo.winTitle": "Congratulations!",
    "solo.winDetail": "You got it in %d tries!\nAnswer: %@",
    "solo.loseTitle": "Too bad!",
    "solo.loseDetail": "You couldn't guess in %d tries.\nAnswer: %@",

    // Create Room
    "create.myInfo": "My Info",
    "create.name": "Name",
    "create.mode": "Mode",
    "create.simultaneous": "Simultaneous",
    "create.turn": "Turn-based",
    "create.button": "Create Room",
    "create.title": "Create Room",
    "create.visibility": "Visibility",
    "create.publicToggle": "Public Room",
    "create.publicHint": "Anyone with the group code can find and join this room.",
    "create.groupSection": "Group",
    "create.groupMode": "Group",
    "create.newGroup": "New Group",
    "create.existingGroup": "Existing",
    "create.noGroups": "No groups found.",
    "create.rooms": "rooms",

    // Join Room
    "join.myInfo": "My Info",
    "join.name": "Name",
    "join.roomCode": "Room Code",
    "join.button": "Join",
    "join.title": "Join Room",
    "join.enterCode": "Enter Code",
    "join.browsePublic": "Browse Public",
    "join.groupCodePlaceholder": "Group (e.g. A3F)",
    "join.search": "Search",
    "join.noPublicRooms": "No public rooms found.",
    "join.group": "Group: %@",
    "join.nameRequired": "Enter your name first",

    // Multiplayer (RoomFlowView)
    "multi.title": "Multiplayer",
    "multi.leave": "Leave",
    "multi.me": "Me",
    "multi.opponent": "Opponent",
    "multi.turnMode": "Turn",
    "multi.simMode": "Simul",
    "multi.commitSection": "Set your answer (3 digits, no duplicates)",
    "multi.commitPlaceholder": "e.g. 123",
    "multi.commitButton": "Commit (Lock)",
    "multi.committed": "Committed",
    "multi.waiting": "Waiting",
    "multi.waitingOpponent": "Waiting for opponent...",
    "multi.turnLobbyDesc": "Game starts when both players join.\nServer picks the answer, take turns guessing.",
    "multi.joined": "Joined",
    "multi.emptyHistory": "No guesses yet",
    "multi.opponentTurn": "Waiting for opponent's turn...",
    "multi.guessPlaceholder": "3-digit guess",
    "multi.submit": "Submit",
    "multi.attempts": " attempts",
    "multi.draw": "Draw!",
    "multi.win": "Victory!",
    "multi.lose": "Defeat",
    "multi.winCheat": "Win: opponent cheated",
    "multi.loseCheat": "Lose: commit mismatch",
    "multi.winDisconnect": "Win: opponent left",
    "multi.loseDisconnect": "Lose: disconnected",
    "multi.result": "Result: %@",
    "multi.groupCode": "Group: %@",
    "multi.shareGroupCode": "Share this group code",

    // RoomService Errors
    "error.roomNotFound": "Room not found.",
    "error.roomFinished": "This room has already ended.",
    "error.roomFull": "This room is already full.",
    "error.invalidSecret": "Answer must be 3 unique digits.",
    "error.invalidGuess": "Guess must be 3 unique digits.",
    "error.notYourTurn": "It's your opponent's turn.",

    // BaseballError
    "error.notThreeDigits": "Please enter a 3-digit number",
    "error.repeatingDigits": "Digits must not repeat",

    // How to Play
    "help.title": "How to Play",
    "help.goal": "Goal",
    "help.goalDesc": "Guess the secret 3-digit number with no repeating digits.",
    "help.feedback": "Feedback",
    "help.strikeDesc": "S (Strike) — Correct digit in the correct position",
    "help.ballDesc": "B (Ball) — Correct digit in the wrong position",
    "help.outDesc": "OUT — No correct digits at all",
    "help.rules": "Rules",
    "help.rule1": "The secret number has 3 digits (0–9), each used only once.",
    "help.rule2": "Your guess must also have 3 unique digits.",
    "help.rule3": "Invalid: 112, 555, 000 (repeating digits)",
    "help.example": "Example",
    "help.exampleTitle": "Secret: 8 9 4",
    "help.ex1": "Guess 123 → OUT (eliminate 1,2,3)",
    "help.ex2": "Guess 456 → 1B (one of 4,5,6 correct)",
    "help.ex3": "Guess 789 → 2B (two of 7,8,9 correct)",
    "help.ex4": "Guess 489 → 3B (all correct, wrong positions)",
    "help.ex5": "Guess 849 → 1S 2B (getting closer)",
    "help.ex6": "Guess 894 → 3S — You win!",

    // Footer
    "footer.company": "© sinbiroum.com",

    // League
    "league.title": "CPU League",
    "league.desc": "Beat CPUs, earn keys, climb the ranks",
    "league.badge": "LEAGUE",
    "league.level": "Level %d",
    "league.levelName.1": "Beginner",
    "league.levelName.2": "Intermediate",
    "league.levelName.3": "Advanced",
    "league.levelName.4": "Expert",
    "league.levelName.5": "Master",
    "league.levelName.6": "Grandmaster",
    "league.readyToPlay": "Ready to Play",
    "league.keyExpires": "Key expires in %@",
    "league.needKey": "Need Level %d Key",
    "league.enterName": "Enter Your Name",
    "match.title": "Match vs %@",
    "match.bestOf3": "Single Game",
    "match.game": "Game %d",
    "match.waiting": "Waiting for match...",
    "match.connecting": "Connecting...",
    "match.preparingGame": "Preparing next game...",
    "match.inGame": "Game in progress",
    "match.you": "You",
    "match.vs": "vs %@",
    "match.win": "Match Won!",
    "match.lose": "Match Lost",
    "match.gameWin": "Win",
    "match.gameLose": "Loss",
    "match.rounds": "rounds",
    "match.keyEarned": "Level %d Unlocked!",
    "match.allCleared": "All levels cleared!",
    "match.backToLeague": "Back to League",
    "match.retry": "Retry",
    "match.nextLevel": "Next Level %d",
    "match.leave": "Leave Match",
    "match.nextGame": "Next Game",

    // Bonus Level
    "bonus.unlocked": "Bonus stage unlocked!",
    "bonus.challenge": "Bonus Challenge",
    "bonus.cleared": "Bonus stage cleared!",

    // Sharing
    "share.inviteButton": "Invite Friend",
    "share.resultButton": "Share Result",
    "share.roomInvite": "Number Baseball challenge! Room code: %@",
    "share.soloWin": "Number Baseball 🎉 Solved in %d tries! Can you beat that?",
    "share.soloLose": "Number Baseball 💪 Tried %d times! Can you do better?",
    "share.multiWin": "Number Baseball 🏆 Won in %d guesses! Play with me!",
    "share.multiLose": "Number Baseball 💪 Lost but I'll be back! Play with me!",
    "share.multiDraw": "Number Baseball 🤝 It was a draw! Join the fun!",

    // League misc
    "league.noBots": "No bots available right now. Please try again later.",

    // Post-game overlay
    "postgame.oneMore": "One More",
    "postgame.leave": "Leave",
    "postgame.myAttempts": "Me",
    "postgame.oppAttempts": "Opponent",
    "postgame.waiting": "Waiting for opponent...",
  ]

  // MARK: - Korean Strings
  private static let ko: [String: String] = [
    // Main Menu
    "app.title": "숫자야구",
    "app.subtitle": "Number Baseball",
    "menu.createRoom": "방 만들기",
    "menu.createRoom.desc": "친구를 초대하세요",
    "menu.joinRoom": "방 입장",
    "menu.joinRoom.desc": "코드로 참여",
    "menu.aiBattle": "CPU 대전",
    "menu.aiBattle.desc": "CPU와 숫자야구 대결",
    "menu.aiBattle.badge": "CPU",
    "menu.friends": "친구와 대전",
    "menu.friends.desc": "방을 만들거나 입장",
    "menu.solo": "혼자하기",
    "menu.solo.desc": "혼자서 연습하기",
    "common.error": "오류",
    "common.ok": "확인",
    "common.close": "닫기",

    // Solo Game
    "solo.title": "혼자하기",
    "solo.guess": "추측하기",
    "solo.newGame": "새 게임",
    "solo.showAnswer": "정답 보기",
    "solo.answer": "정답: %@",
    "solo.emptyHint": "3자리 숫자를 입력하세요 (중복 금지)",
    "solo.alert": "알림",
    "solo.winTitle": "축하합니다!",
    "solo.winDetail": "%d번 만에 맞추셨습니다!\n정답: %@",
    "solo.loseTitle": "아쉽네요!",
    "solo.loseDetail": "%d번 시도했지만 못 맞췄습니다.\n정답: %@",

    // Create Room
    "create.myInfo": "내 정보",
    "create.name": "이름",
    "create.mode": "모드",
    "create.simultaneous": "동시대결",
    "create.turn": "턴제",
    "create.button": "방 만들기",
    "create.title": "방 만들기",
    "create.visibility": "공개 설정",
    "create.publicToggle": "공개 방",
    "create.publicHint": "그룹 코드를 가진 누구나 이 방을 찾아 입장할 수 있어요.",
    "create.groupSection": "그룹",
    "create.groupMode": "그룹",
    "create.newGroup": "새 그룹",
    "create.existingGroup": "기존 그룹",
    "create.noGroups": "기존 그룹이 없어요.",
    "create.rooms": "개 방",

    // Join Room
    "join.myInfo": "내 정보",
    "join.name": "이름",
    "join.roomCode": "방 코드",
    "join.button": "입장",
    "join.title": "방 입장",
    "join.enterCode": "코드 입력",
    "join.browsePublic": "공개 방 찾기",
    "join.groupCodePlaceholder": "그룹 (예: A3F)",
    "join.search": "검색",
    "join.noPublicRooms": "공개 방이 없어요.",
    "join.group": "그룹: %@",
    "join.nameRequired": "이름을 먼저 입력하세요",

    // Multiplayer (RoomFlowView)
    "multi.title": "멀티플레이",
    "multi.leave": "나가기",
    "multi.me": "나",
    "multi.opponent": "상대",
    "multi.turnMode": "턴제",
    "multi.simMode": "동시",
    "multi.commitSection": "내 정답 설정 (3자리 · 중복 금지)",
    "multi.commitPlaceholder": "예: 123",
    "multi.commitButton": "커밋(잠금)",
    "multi.committed": "커밋 완료",
    "multi.waiting": "대기중",
    "multi.waitingOpponent": "상대 플레이어를 기다리는 중...",
    "multi.turnLobbyDesc": "두 명이 입장하면 자동으로 게임이 시작됩니다.\n서버가 정답을 정하고, 교대로 추측합니다.",
    "multi.joined": "입장 완료",
    "multi.emptyHistory": "아직 추측 기록이 없어요",
    "multi.opponentTurn": "상대 턴 대기중...",
    "multi.guessPlaceholder": "3자리 추측",
    "multi.submit": "제출",
    "multi.attempts": "회",
    "multi.draw": "무승부!",
    "multi.win": "승리!",
    "multi.lose": "패배",
    "multi.winCheat": "상대 부정행위로 승리",
    "multi.loseCheat": "커밋 불일치 패배",
    "multi.winDisconnect": "상대 이탈로 승리",
    "multi.loseDisconnect": "이탈 패배",
    "multi.result": "결과: %@",
    "multi.groupCode": "그룹: %@",
    "multi.shareGroupCode": "이 그룹 코드를 공유하세요",

    // RoomService Errors
    "error.roomNotFound": "방이 없습니다.",
    "error.roomFinished": "이미 끝난 방입니다.",
    "error.roomFull": "이미 2명이 참가한 방입니다.",
    "error.invalidSecret": "정답은 중복 없는 3자리 숫자여야 해요.",
    "error.invalidGuess": "추측은 중복 없는 3자리 숫자여야 해요.",
    "error.notYourTurn": "지금은 상대 턴이에요.",

    // BaseballError
    "error.notThreeDigits": "3자리 숫자를 입력하세요",
    "error.repeatingDigits": "중복되지 않는 숫자를 입력하세요",

    // How to Play
    "help.title": "게임 방법",
    "help.goal": "목표",
    "help.goalDesc": "숫자가 겹치지 않는 비밀 3자리 숫자를 맞추세요.",
    "help.feedback": "피드백",
    "help.strikeDesc": "S (스트라이크) — 숫자와 위치 모두 맞음",
    "help.ballDesc": "B (볼) — 숫자는 맞지만 위치가 다름",
    "help.outDesc": "OUT — 맞는 숫자가 없음",
    "help.rules": "규칙",
    "help.rule1": "비밀 번호는 3자리 (0~9)이며 각 숫자는 한 번만 사용됩니다.",
    "help.rule2": "추측도 중복 없는 3자리 숫자여야 합니다.",
    "help.rule3": "불가: 112, 555, 000 (숫자 중복)",
    "help.example": "예시",
    "help.exampleTitle": "정답: 8 9 4",
    "help.ex1": "추측 123 → OUT (1,2,3 제거)",
    "help.ex2": "추측 456 → 1B (4,5,6 중 하나 맞음)",
    "help.ex3": "추측 789 → 2B (7,8,9 중 둘 맞음)",
    "help.ex4": "추측 489 → 3B (모두 맞지만 위치 다름)",
    "help.ex5": "추측 849 → 1S 2B (거의 다 왔다!)",
    "help.ex6": "추측 894 → 3S — 정답!",

    // Footer
    "footer.company": "© sinbiroum.com",

    // League
    "league.title": "CPU 리그",
    "league.desc": "CPU를 이기고, 키를 얻고, 랭크를 올려보세요",
    "league.badge": "리그",
    "league.level": "레벨 %d",
    "league.levelName.1": "초보",
    "league.levelName.2": "중급",
    "league.levelName.3": "고급",
    "league.levelName.4": "전문가",
    "league.levelName.5": "마스터",
    "league.levelName.6": "그랜드마스터",
    "league.readyToPlay": "플레이 준비 완료",
    "league.keyExpires": "키 유효기간: %@",
    "league.needKey": "레벨 %d 키 필요",
    "league.enterName": "이름을 입력하세요",
    "match.title": "%@ 와 매치",
    "match.bestOf3": "단판제",
    "match.game": "게임 %d",
    "match.waiting": "매치 대기 중...",
    "match.connecting": "연결 중...",
    "match.preparingGame": "다음 게임 준비 중...",
    "match.inGame": "게임 진행 중",
    "match.you": "나",
    "match.vs": "vs %@",
    "match.win": "매치 승리!",
    "match.lose": "매치 패배",
    "match.gameWin": "승리",
    "match.gameLose": "패배",
    "match.rounds": "라운드",
    "match.keyEarned": "레벨 %d 잠금해제!",
    "match.allCleared": "모든 레벨 클리어!",
    "match.backToLeague": "리그로 돌아가기",
    "match.retry": "다시 도전",
    "match.nextLevel": "다음 레벨 %d 도전",
    "match.leave": "매치 나가기",
    "match.nextGame": "다음 게임",

    // Bonus Level
    "bonus.unlocked": "보너스 스테이지 해금!",
    "bonus.challenge": "보너스 도전",
    "bonus.cleared": "보너스 스테이지 클리어!",

    // Sharing
    "share.inviteButton": "친구 초대",
    "share.resultButton": "결과 공유",
    "share.roomInvite": "숫자야구 대결 신청! 방 코드: %@",
    "share.soloWin": "숫자야구 🎉 %d번 만에 맞췄어요! 당신도 도전해보세요!",
    "share.soloLose": "숫자야구 💪 %d번 시도했어요! 당신은 맞출 수 있을까요?",
    "share.multiWin": "숫자야구 승리! 🏆 %d번 만에 이겼어요! 같이 해봐요!",
    "share.multiLose": "숫자야구 패배... 💪 다음엔 이길 거야! 같이 도전해봐요!",
    "share.multiDraw": "숫자야구 무승부! 🤝 팽팽한 대결이었어요! 같이 해봐요!",

    // League misc
    "league.noBots": "지금은 봇이 없어요. 잠시 후 다시 시도해주세요.",

    // Post-game overlay
    "postgame.oneMore": "한판 더",
    "postgame.leave": "메뉴로",
    "postgame.myAttempts": "나",
    "postgame.oppAttempts": "상대",
    "postgame.waiting": "상대 동의 대기 중...",
  ]

  // MARK: - Japanese Strings
  private static let ja: [String: String] = [
    // Main Menu
    "app.title": "数字野球",
    "app.subtitle": "Number Baseball",
    "menu.createRoom": "ルーム作成",
    "menu.createRoom.desc": "友達を招待しよう",
    "menu.joinRoom": "ルーム参加",
    "menu.joinRoom.desc": "コードで参加",
    "menu.aiBattle": "CPU対戦",
    "menu.aiBattle.desc": "CPUと数字野球で対決",
    "menu.aiBattle.badge": "CPU",
    "menu.friends": "友達と対戦",
    "menu.friends.desc": "ルームを作成・参加",
    "menu.solo": "一人プレイ",
    "menu.solo.desc": "一人で練習",
    "common.error": "エラー",
    "common.ok": "OK",
    "common.close": "閉じる",

    // Solo Game
    "solo.title": "一人プレイ",
    "solo.guess": "推測する",
    "solo.newGame": "新しいゲーム",
    "solo.showAnswer": "答えを見る",
    "solo.answer": "答え: %@",
    "solo.emptyHint": "3桁の数字を入力（重複なし）",
    "solo.alert": "お知らせ",
    "solo.winTitle": "おめでとうございます！",
    "solo.winDetail": "%d回で正解しました！\n答え: %@",
    "solo.loseTitle": "残念！",
    "solo.loseDetail": "%d回挑戦しましたが正解できませんでした。\n答え: %@",

    // Create Room
    "create.myInfo": "プロフィール",
    "create.name": "名前",
    "create.mode": "モード",
    "create.simultaneous": "同時対戦",
    "create.turn": "ターン制",
    "create.button": "ルーム作成",
    "create.title": "ルーム作成",
    "create.visibility": "公開設定",
    "create.publicToggle": "公開ルーム",
    "create.publicHint": "グループコードを知っている人は誰でもこのルームを見つけて参加できます。",
    "create.groupSection": "グループ",
    "create.groupMode": "グループ",
    "create.newGroup": "新規グループ",
    "create.existingGroup": "既存",
    "create.noGroups": "グループがありません。",
    "create.rooms": "ルーム",

    // Join Room
    "join.myInfo": "プロフィール",
    "join.name": "名前",
    "join.roomCode": "ルームコード",
    "join.button": "参加",
    "join.title": "ルーム参加",
    "join.enterCode": "コード入力",
    "join.browsePublic": "公開ルーム検索",
    "join.groupCodePlaceholder": "グループ (例: A3F)",
    "join.search": "検索",
    "join.noPublicRooms": "公開ルームが見つかりません。",
    "join.group": "グループ: %@",
    "join.nameRequired": "先に名前を入力してください",

    // Multiplayer (RoomFlowView)
    "multi.title": "マルチプレイ",
    "multi.leave": "退出",
    "multi.me": "自分",
    "multi.opponent": "相手",
    "multi.turnMode": "ターン",
    "multi.simMode": "同時",
    "multi.commitSection": "答えを設定（3桁・重複なし）",
    "multi.commitPlaceholder": "例: 123",
    "multi.commitButton": "コミット（ロック）",
    "multi.committed": "コミット済み",
    "multi.waiting": "待機中",
    "multi.waitingOpponent": "相手プレイヤーを待っています...",
    "multi.turnLobbyDesc": "二人が入室するとゲームが自動開始します。\nサーバーが答えを決め、交互に推測します。",
    "multi.joined": "入室完了",
    "multi.emptyHistory": "まだ推測記録がありません",
    "multi.opponentTurn": "相手のターンを待っています...",
    "multi.guessPlaceholder": "3桁の推測",
    "multi.submit": "送信",
    "multi.attempts": "回",
    "multi.draw": "引き分け！",
    "multi.win": "勝利！",
    "multi.lose": "敗北",
    "multi.winCheat": "相手の不正で勝利",
    "multi.loseCheat": "コミット不一致で敗北",
    "multi.winDisconnect": "相手の切断で勝利",
    "multi.loseDisconnect": "切断で敗北",
    "multi.result": "結果: %@",
    "multi.groupCode": "グループ: %@",
    "multi.shareGroupCode": "このグループコードを共有してください",

    // RoomService Errors
    "error.roomNotFound": "ルームが見つかりません。",
    "error.roomFinished": "すでに終了したルームです。",
    "error.roomFull": "すでに2人が参加しています。",
    "error.invalidSecret": "答えは重複のない3桁の数字にしてください。",
    "error.invalidGuess": "推測は重複のない3桁の数字にしてください。",
    "error.notYourTurn": "今は相手のターンです。",

    // BaseballError
    "error.notThreeDigits": "3桁の数字を入力してください",
    "error.repeatingDigits": "重複のない数字を入力してください",

    // How to Play
    "help.title": "遊び方",
    "help.goal": "目標",
    "help.goalDesc": "数字が重複しない秘密の3桁の数字を当ててください。",
    "help.feedback": "フィードバック",
    "help.strikeDesc": "S（ストライク）— 数字も位置も正解",
    "help.ballDesc": "B（ボール）— 数字は正解だが位置が違う",
    "help.outDesc": "OUT — 正解の数字なし",
    "help.rules": "ルール",
    "help.rule1": "秘密の番号は3桁（0〜9）で、各数字は一度だけ使用されます。",
    "help.rule2": "推測も重複のない3桁の数字でなければなりません。",
    "help.rule3": "無効: 112, 555, 000（数字の重複）",
    "help.example": "例",
    "help.exampleTitle": "答え: 8 9 4",
    "help.ex1": "推測 123 → OUT（1,2,3を除外）",
    "help.ex2": "推測 456 → 1B（4,5,6のうち1つ正解）",
    "help.ex3": "推測 789 → 2B（7,8,9のうち2つ正解）",
    "help.ex4": "推測 489 → 3B（全て正解だが位置違い）",
    "help.ex5": "推測 849 → 1S 2B（もう少し！）",
    "help.ex6": "推測 894 → 3S — 正解！",

    // Footer
    "footer.company": "© sinbiroum.com",

    // League
    "league.title": "CPUリーグ",
    "league.desc": "CPUを倒してキーを獲得し、ランクを上げよう",
    "league.badge": "リーグ",
    "league.level": "レベル %d",
    "league.levelName.1": "初心者",
    "league.levelName.2": "中級者",
    "league.levelName.3": "上級者",
    "league.levelName.4": "エキスパート",
    "league.levelName.5": "マスター",
    "league.levelName.6": "グランドマスター",
    "league.readyToPlay": "プレイ準備完了",
    "league.keyExpires": "キー有効期限: %@",
    "league.needKey": "レベル %d のキーが必要",
    "league.enterName": "名前を入力してください",
    "match.title": "%@ とマッチ",
    "match.bestOf3": "一本勝負",
    "match.game": "ゲーム %d",
    "match.waiting": "マッチ待機中...",
    "match.connecting": "接続中...",
    "match.preparingGame": "次のゲームを準備中...",
    "match.inGame": "ゲーム進行中",
    "match.you": "あなた",
    "match.vs": "vs %@",
    "match.win": "マッチ勝利！",
    "match.lose": "マッチ敗北",
    "match.gameWin": "勝ち",
    "match.gameLose": "負け",
    "match.rounds": "ラウンド",
    "match.keyEarned": "レベル %d 解放！",
    "match.allCleared": "全レベルクリア！",
    "match.backToLeague": "リーグに戻る",
    "match.retry": "リトライ",
    "match.nextLevel": "次のレベル %d に挑戦",
    "match.leave": "マッチを離れる",
    "match.nextGame": "次のゲーム",

    // Bonus Level
    "bonus.unlocked": "ボーナスステージ解放！",
    "bonus.challenge": "ボーナスチャレンジ",
    "bonus.cleared": "ボーナスステージクリア！",

    // Sharing
    "share.inviteButton": "友達を招待",
    "share.resultButton": "結果をシェア",
    "share.roomInvite": "数字野球で対決しよう！ルームコード: %@",
    "share.soloWin": "数字野球 🎉 %d回で正解！あなたも挑戦してみて！",
    "share.soloLose": "数字野球 💪 %d回挑戦！あなたはできる？",
    "share.multiWin": "数字野球 🏆 %d回で勝利！一緒に遊ぼう！",
    "share.multiLose": "数字野球 💪 負けたけど次は勝つ！一緒に遊ぼう！",
    "share.multiDraw": "数字野球 🤝 引き分け！一緒に遊ぼう！",

    // League misc
    "league.noBots": "ボットが見つかりません。後でもう一度試してください。",

    // Post-game overlay
    "postgame.oneMore": "もう一回",
    "postgame.leave": "メニューへ",
    "postgame.myAttempts": "自分",
    "postgame.oppAttempts": "相手",
    "postgame.waiting": "相手の返答を待っています...",
  ]

  // MARK: - Spanish Strings
  private static let es: [String: String] = [
    // Main Menu
    "app.title": "Béisbol Numérico",
    "app.subtitle": "Number Baseball",
    "menu.createRoom": "Crear sala",
    "menu.createRoom.desc": "Invita a tus amigos",
    "menu.joinRoom": "Unirse",
    "menu.joinRoom.desc": "Unirse con código",
    "menu.aiBattle": "Batalla CPU",
    "menu.aiBattle.desc": "Desafia a oponentes CPU",
    "menu.aiBattle.badge": "CPU",
    "menu.friends": "Con amigos",
    "menu.friends.desc": "Crea o entra a una sala",
    "menu.solo": "Jugar solo",
    "menu.solo.desc": "Practica solo",
    "common.error": "Error",
    "common.ok": "OK",
    "common.close": "Cerrar",

    // Solo Game
    "solo.title": "Jugar solo",
    "solo.guess": "Adivinar",
    "solo.newGame": "Nuevo juego",
    "solo.showAnswer": "Ver respuesta",
    "solo.answer": "Respuesta: %@",
    "solo.emptyHint": "Ingresa un número de 3 dígitos (sin repetir)",
    "solo.alert": "Aviso",
    "solo.winTitle": "¡Felicidades!",
    "solo.winDetail": "¡Lo adivinaste en %d intentos!\nRespuesta: %@",
    "solo.loseTitle": "¡Qué lástima!",
    "solo.loseDetail": "No pudiste adivinar en %d intentos.\nRespuesta: %@",

    // Create Room
    "create.myInfo": "Mi info",
    "create.name": "Nombre",
    "create.mode": "Modo",
    "create.simultaneous": "Simultáneo",
    "create.turn": "Por turnos",
    "create.button": "Crear sala",
    "create.title": "Crear sala",
    "create.visibility": "Visibilidad",
    "create.publicToggle": "Sala pública",
    "create.publicHint": "Cualquiera con el código de grupo puede encontrar y unirse a esta sala.",
    "create.groupSection": "Grupo",
    "create.groupMode": "Grupo",
    "create.newGroup": "Nuevo grupo",
    "create.existingGroup": "Existente",
    "create.noGroups": "No hay grupos.",
    "create.rooms": "salas",

    // Join Room
    "join.myInfo": "Mi info",
    "join.name": "Nombre",
    "join.roomCode": "Código de sala",
    "join.button": "Unirse",
    "join.title": "Unirse a sala",
    "join.enterCode": "Ingresar código",
    "join.browsePublic": "Buscar públicas",
    "join.groupCodePlaceholder": "Grupo (ej. A3F)",
    "join.search": "Buscar",
    "join.noPublicRooms": "No se encontraron salas públicas.",
    "join.group": "Grupo: %@",
    "join.nameRequired": "Ingresa tu nombre primero",

    // Multiplayer (RoomFlowView)
    "multi.title": "Multijugador",
    "multi.leave": "Salir",
    "multi.me": "Yo",
    "multi.opponent": "Rival",
    "multi.turnMode": "Turnos",
    "multi.simMode": "Simul",
    "multi.commitSection": "Elige tu respuesta (3 dígitos, sin repetir)",
    "multi.commitPlaceholder": "ej. 123",
    "multi.commitButton": "Confirmar (Bloquear)",
    "multi.committed": "Confirmado",
    "multi.waiting": "Esperando",
    "multi.waitingOpponent": "Esperando al rival...",
    "multi.turnLobbyDesc": "El juego comienza cuando ambos jugadores entren.\nEl servidor elige la respuesta, adivinen por turnos.",
    "multi.joined": "Conectado",
    "multi.emptyHistory": "Aún no hay intentos",
    "multi.opponentTurn": "Esperando el turno del rival...",
    "multi.guessPlaceholder": "3 dígitos",
    "multi.submit": "Enviar",
    "multi.attempts": " intentos",
    "multi.draw": "¡Empate!",
    "multi.win": "¡Victoria!",
    "multi.lose": "Derrota",
    "multi.winCheat": "Victoria: rival hizo trampa",
    "multi.loseCheat": "Derrota: confirmación inválida",
    "multi.winDisconnect": "Victoria: rival desconectado",
    "multi.loseDisconnect": "Derrota: desconectado",
    "multi.result": "Resultado: %@",
    "multi.groupCode": "Grupo: %@",
    "multi.shareGroupCode": "Comparte este código de grupo",

    // RoomService Errors
    "error.roomNotFound": "Sala no encontrada.",
    "error.roomFinished": "Esta sala ya ha terminado.",
    "error.roomFull": "Esta sala ya está llena.",
    "error.invalidSecret": "La respuesta debe tener 3 dígitos únicos.",
    "error.invalidGuess": "El intento debe tener 3 dígitos únicos.",
    "error.notYourTurn": "Es el turno de tu rival.",

    // BaseballError
    "error.notThreeDigits": "Ingresa un número de 3 dígitos",
    "error.repeatingDigits": "Los dígitos no deben repetirse",

    // How to Play
    "help.title": "Cómo jugar",
    "help.goal": "Objetivo",
    "help.goalDesc": "Adivina el número secreto de 3 dígitos sin dígitos repetidos.",
    "help.feedback": "Pistas",
    "help.strikeDesc": "S (Strike) — Dígito correcto en la posición correcta",
    "help.ballDesc": "B (Ball) — Dígito correcto en posición incorrecta",
    "help.outDesc": "OUT — Ningún dígito correcto",
    "help.rules": "Reglas",
    "help.rule1": "El número secreto tiene 3 dígitos (0–9), cada uno usado solo una vez.",
    "help.rule2": "Tu intento también debe tener 3 dígitos únicos.",
    "help.rule3": "Inválido: 112, 555, 000 (dígitos repetidos)",
    "help.example": "Ejemplo",
    "help.exampleTitle": "Secreto: 8 9 4",
    "help.ex1": "Intento 123 → OUT (eliminar 1,2,3)",
    "help.ex2": "Intento 456 → 1B (uno de 4,5,6 correcto)",
    "help.ex3": "Intento 789 → 2B (dos de 7,8,9 correctos)",
    "help.ex4": "Intento 489 → 3B (todos correctos, posición incorrecta)",
    "help.ex5": "Intento 849 → 1S 2B (¡casi!)",
    "help.ex6": "Intento 894 → 3S — ¡Ganaste!",

    // Footer
    "footer.company": "© sinbiroum.com",

    // League
    "league.title": "Liga CPU",
    "league.desc": "Vence CPUs, consigue llaves y sube de rango",
    "league.badge": "LIGA",
    "league.level": "Nivel %d",
    "league.levelName.1": "Principiante",
    "league.levelName.2": "Intermedio",
    "league.levelName.3": "Avanzado",
    "league.levelName.4": "Experto",
    "league.levelName.5": "Maestro",
    "league.levelName.6": "Gran Maestro",
    "league.readyToPlay": "Listo para jugar",
    "league.keyExpires": "Clave expira en %@",
    "league.needKey": "Necesitas llave del Nivel %d",
    "league.enterName": "Ingresa tu nombre",
    "match.title": "Partido vs %@",
    "match.bestOf3": "Juego único",
    "match.game": "Juego %d",
    "match.waiting": "Esperando partido...",
    "match.connecting": "Conectando...",
    "match.preparingGame": "Preparando siguiente juego...",
    "match.inGame": "Juego en curso",
    "match.you": "Tú",
    "match.vs": "vs %@",
    "match.win": "¡Partido ganado!",
    "match.lose": "Partido perdido",
    "match.gameWin": "Victoria",
    "match.gameLose": "Derrota",
    "match.rounds": "rondas",
    "match.keyEarned": "¡Nivel %d desbloqueado!",
    "match.allCleared": "¡Todos los niveles completados!",
    "match.backToLeague": "Volver a la Liga",
    "match.retry": "Reintentar",
    "match.nextLevel": "Siguiente Nivel %d",
    "match.leave": "Salir del partido",
    "match.nextGame": "Siguiente juego",
    "bonus.unlocked": "¡Etapa bonus desbloqueada!",
    "bonus.challenge": "Desafío Bonus",
    "bonus.cleared": "¡Etapa bonus completada!",

    // Sharing
    "share.inviteButton": "Invitar amigo",
    "share.resultButton": "Compartir resultado",
    "share.roomInvite": "¡Desafío de Béisbol Numérico! Código: %@",
    "share.soloWin": "Béisbol Numérico 🎉 ¡Lo adivine en %d intentos! ¿Puedes superarlo?",
    "share.soloLose": "Béisbol Numérico 💪 ¡%d intentos! ¿Puedes hacerlo mejor?",
    "share.multiWin": "Béisbol Numérico 🏆 ¡Gané en %d intentos! ¡Juega conmigo!",
    "share.multiLose": "Béisbol Numérico 💪 ¡Perdí pero volveré! ¡Juega conmigo!",
    "share.multiDraw": "Béisbol Numérico 🤝 ¡Empate! ¡Únete al juego!",

    // League misc
    "league.noBots": "No hay bots disponibles ahora. Inténtalo más tarde.",

    // Post-game overlay
    "postgame.oneMore": "Una más",
    "postgame.leave": "Salir",
    "postgame.myAttempts": "Yo",
    "postgame.oppAttempts": "Rival",
  ]
}
