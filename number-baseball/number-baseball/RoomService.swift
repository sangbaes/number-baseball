import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

@MainActor
final class RoomService: ObservableObject {

  // MARK: Localization
  var loc: LocalizationManager?

  // MARK: Published state
  @Published var roomCode: String = ""
  @Published var playerId: String = ""           // "p1" or "p2"
  @Published var playerName: String = ""
  @Published var status: String = "idle"         // idle/lobby/playing/finished
  @Published var gameMode: String = "simultaneous" // simultaneous/turn
  @Published var hostId: String = "p1"

  @Published var players: [String: PlayerInfo] = [:]
  @Published var commits: Set<String> = []       // players who committed
  @Published var rounds: [Int: RoundState] = [:]
  @Published var outcome: OutcomeState? = nil

  // 턴제: 서버가 정한 정답 (Firebase에서 읽어옴)
  @Published var turnSecret: String? = nil

  // Public room / Group
  @Published var isPublic: Bool = false
  @Published var groupCode: String = ""
  @Published var publicRooms: [PublicRoomEntry] = []
  @Published var availableGroups: [GroupEntry] = []

  // Match context (league mode)
  @Published var matchId: String? = nil
  @Published var matchGame: Int = 0
  @Published var level: Int = 0

  // Assigned worker (league mode — for cleanup)
  @Published var assignedWorkerId: String? = nil

  // for UI
  @Published var errorMessage: String? = nil

  // Rematch (한판 더)
  @Published var rematchRequests: Set<String> = []   // "p1"/"p2" 동의한 플레이어
  @Published var rematchNewRoomCode: String? = nil    // p1이 만든 새 방 코드

  // MARK: Local secret (동시대결 전용)
  private var mySecret: String? = nil
  private var mySalt: String? = nil
  private var myCommitHash: String? = nil

  // MARK: Firebase
  private lazy var db = Database.database().reference()
  private var roomRef: DatabaseReference? = nil
  private var roomHandle: DatabaseHandle? = nil
  private var offsetHandle: DatabaseHandle? = nil
  private var serverOffsetMs: Int64 = 0

  // Public rooms listener
  private var publicRoomsRef: DatabaseReference? = nil
  private var publicRoomsHandle: DatabaseHandle? = nil

  // Draw window
  private let DRAW_WINDOW_MS: Int64 = 1500

  // Turn-based state (stored in DB)
  @Published var currentTurn: String? = nil // "p1" or "p2" (only for turn mode)

  // MARK: Time helpers
  private func serverNowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000.0) + serverOffsetMs
  }

  func startServerOffsetListener() {
    let infoRef = db.child(".info/serverTimeOffset")
    offsetHandle = infoRef.observe(.value) { [weak self] snap in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let v = snap.value as? Double { self.serverOffsetMs = Int64(v) }
        else if let v = snap.value as? Int64 { self.serverOffsetMs = v }
      }
    }
  }

  func stopAllObservers() {
    if let rr = roomRef, let h = roomHandle { rr.removeObserver(withHandle: h) }
    if let h = offsetHandle { db.child(".info/serverTimeOffset").removeObserver(withHandle: h) }
    roomHandle = nil
    offsetHandle = nil
    roomRef = nil
    stopPublicRoomsListener()
  }

  // MARK: Room code
  private func genCode() -> String {
    let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<5).compactMap { _ in chars.randomElement() })
  }

  private func genGroupCode() -> String {
    let chars = Array("0123456789ABCDEF")
    return String((0..<3).compactMap { _ in chars.randomElement() })
  }

  // MARK: Create / Join
  func createRoom(name: String, mode: String, isPublic: Bool = false, existingGroupCode: String? = nil) {
    errorMessage = nil

    // 상태를 즉시 lobby로 설정: leaveRoom → createRoom 연속 호출 시
    // SwiftUI가 "idle" 중간 상태를 보지 않도록 동기적으로 선점
    status = "lobby"
    playerId = "p1"
    playerName = name
    gameMode = mode
    roomCode = genCode()
    self.isPublic = isPublic
    self.groupCode = isPublic ? (existingGroupCode ?? genGroupCode()) : ""

    let rr = db.child("rooms").child(roomCode)
    roomRef = rr

    let uid = Auth.auth().currentUser?.uid ?? ""

    var updates: [String: Any] = [
      "rooms/\(roomCode)/status": "lobby",
      "rooms/\(roomCode)/createdAt": ServerValue.timestamp(),
      "rooms/\(roomCode)/hostId": "p1",
      "rooms/\(roomCode)/gameMode": mode,
      "rooms/\(roomCode)/isPublic": isPublic,
      "rooms/\(roomCode)/currentTurn": (mode == "turn") ? "p1" : NSNull(),
      "rooms/\(roomCode)/players/p1": [
        "name": name,
        "uid": uid,
        "joinedAt": ServerValue.timestamp(),
        "connected": true
      ] as [String: Any]
    ]

    if isPublic {
      updates["rooms/\(roomCode)/groupCode"] = groupCode
      updates["publicRooms/\(groupCode)/\(roomCode)"] = [
        "hostName": name,
        "gameMode": mode,
        "createdAt": ServerValue.timestamp(),
        "playerCount": 1
      ] as [String: Any]
    }

    db.updateChildValues(updates) { [weak self] err, _ in
      guard let self else { return }
      if let err { self.errorMessage = err.localizedDescription; return }
      self.setupPresence()
      self.listenRoom()
    }

    // Auto-cleanup publicRooms entry if host disconnects
    if isPublic {
      db.child("publicRooms/\(groupCode)/\(roomCode)").onDisconnectRemoveValue()
    }
  }

  func joinRoom(code: String, name: String) {
    errorMessage = nil

    // 즉시 상태 설정: navigationDestination이 바로 반응하도록 (createRoom과 동일 패턴)
    status = "lobby"
    playerId = "p2"
    playerName = name
    roomCode = code.uppercased()

    let rr = db.child("rooms").child(roomCode)
    roomRef = rr

    rr.observeSingleEvent(of: .value) { [weak self] snap in
      guard let self else { return }
      guard snap.exists(), let data = snap.value as? [String: Any] else {
        self.errorMessage = self.loc?.t("error.roomNotFound") ?? "Room not found."
        self.status = "idle"; self.roomCode = ""
        return
      }
      let st = data["status"] as? String ?? "lobby"
      if st == "finished" {
        self.errorMessage = self.loc?.t("error.roomFinished") ?? "This room has already ended."
        self.status = "idle"; self.roomCode = ""
        return
      }
      let players = (data["players"] as? [String: Any]) ?? [:]
      if players.keys.contains("p2") {
        self.errorMessage = self.loc?.t("error.roomFull") ?? "This room is already full."
        self.status = "idle"; self.roomCode = ""
        return
      }

      // Read room info before writing p2 — set gameMode early so UI renders correctly
      self.gameMode = data["gameMode"] as? String ?? "simultaneous"
      let roomIsPublic = data["isPublic"] as? Bool ?? false
      let roomGroupCode = data["groupCode"] as? String ?? ""

      let uid = Auth.auth().currentUser?.uid ?? ""
      rr.child("players").child("p2").setValue([
        "name": name,
        "uid": uid,
        "joinedAt": ServerValue.timestamp(),
        "connected": true
      ]) { [weak self] err, _ in
        guard let self else { return }
        if let err { self.errorMessage = err.localizedDescription; return }
        self.setupPresence()
        self.listenRoom()

        // Remove from public index (room is now full)
        if roomIsPublic && !roomGroupCode.isEmpty {
          self.db.child("publicRooms/\(roomGroupCode)/\(self.roomCode)").removeValue()
        }
      }
    }
  }

  // MARK: Create Local CPU Room (League mode)

  /// Creates a room for league mode where iOS is p2 and CPU is p1 (local).
  func createLocalCPURoom(
    cpuName: String,
    level: Int,
    groupCode: String,
    playerName: String
  ) {
    errorMessage = nil

    playerId = "p2"
    self.playerName = playerName
    gameMode = "turn"
    roomCode = genCode()
    self.isPublic = false
    self.groupCode = groupCode
    self.level = level
    self.assignedWorkerId = "local-cpu"

    let rr = db.child("rooms").child(roomCode)
    roomRef = rr

    let uid = Auth.auth().currentUser?.uid ?? ""

    let updates: [String: Any] = [
      "rooms/\(roomCode)/status": "lobby",
      "rooms/\(roomCode)/createdAt": ServerValue.timestamp(),
      "rooms/\(roomCode)/hostId": "p1",
      "rooms/\(roomCode)/gameMode": "turn",
      "rooms/\(roomCode)/isPublic": false,
      "rooms/\(roomCode)/groupCode": groupCode,
      "rooms/\(roomCode)/level": level,
      "rooms/\(roomCode)/currentTurn": "p1",

      // p1 = CPU (local)
      "rooms/\(roomCode)/players/p1": [
        "name": cpuName,
        "joinedAt": ServerValue.timestamp(),
        "connected": true
      ] as [String: Any],

      // p2 = human player
      "rooms/\(roomCode)/players/p2": [
        "name": playerName,
        "uid": uid,
        "joinedAt": ServerValue.timestamp(),
        "connected": true
      ] as [String: Any],
    ]

    db.updateChildValues(updates) { [weak self] err, _ in
      guard let self else { return }
      if let err {
        self.errorMessage = err.localizedDescription
        return
      }
      self.setupPresence()
      self.listenRoom()
    }
  }

  // MARK: Presence
  private func setupPresence() {
    guard let rr = roomRef else { return }
    rr.child("players").child(playerId).child("connected").onDisconnectSetValue(false)
  }

  // MARK: Leave / Cleanup
  func leaveRoom() {
    guard let rr = roomRef else { return }

    // Remove publicRooms entry if host leaves a public room
    if isPublic && playerId == "p1" && !groupCode.isEmpty {
      db.child("publicRooms/\(groupCode)/\(roomCode)").removeValue()
    }

    // remove my player
    rr.child("players").child(playerId).removeValue()

    // Room cleanup
    if assignedWorkerId != nil {
      // League mode: iOS owns the room lifecycle — delete entire room
      rr.removeValue()
    } else {
      // PvP mode: only delete if no players remain
      rr.child("players").observeSingleEvent(of: .value) { snap in
        if !snap.exists() {
          rr.removeValue()
        }
      }
    }

    // local reset
    stopAllObservers()
    roomCode = ""
    playerId = ""
    playerName = ""
    status = "idle"
    gameMode = "simultaneous"
    hostId = "p1"
    players = [:]
    commits = []
    rounds = [:]
    outcome = nil
    currentTurn = nil
    mySecret = nil
    mySalt = nil
    myCommitHash = nil
    turnSecret = nil
    isPublic = false
    groupCode = ""
    matchId = nil
    matchGame = 0
    level = 0
    assignedWorkerId = nil
    rematchRequests = []
    rematchNewRoomCode = nil
  }

  // MARK: Rematch

  /// 현재 방에 "한판 더" 의사를 Firebase에 기록
  func requestRematch() {
    roomRef?.child("rematch").child(playerId).setValue(true)
  }

  /// p1 전용: 새 방을 만들고 코드를 구 방 Firebase에 기록 후 전환
  func performRematchAsHost(name: String, mode: String) {
    let newCode = genCode()
    // 1. 구 방에 새 코드 기록 (roomRef 변경 전)
    roomRef?.child("rematch/newRoomCode").setValue(newCode)

    // 2. 구 방 리스너 해제 (leaveRoom 대신 — Firebase 데이터는 보존)
    if let rr = roomRef, let h = roomHandle { rr.removeObserver(withHandle: h) }
    roomHandle = nil

    // 3. 로컬 상태 초기화
    resetLocalGameState(keepPlayer: true)
    status  = "lobby"
    playerId = "p1"
    playerName = name
    gameMode   = mode
    roomCode   = newCode
    isPublic   = false
    groupCode  = ""

    // 4. 새 방 Firebase 쓰기 + 리스닝
    let newRr = db.child("rooms").child(newCode)
    roomRef = newRr
    let uid = Auth.auth().currentUser?.uid ?? ""
    let updates: [String: Any] = [
      "rooms/\(newCode)/status":      "lobby",
      "rooms/\(newCode)/createdAt":   ServerValue.timestamp(),
      "rooms/\(newCode)/hostId":      "p1",
      "rooms/\(newCode)/gameMode":    mode,
      "rooms/\(newCode)/isPublic":    false,
      "rooms/\(newCode)/currentTurn": mode == "turn" ? "p1" : NSNull(),
      "rooms/\(newCode)/players/p1":  [
        "name": name, "uid": uid,
        "joinedAt": ServerValue.timestamp(), "connected": true
      ] as [String: Any]
    ]
    db.updateChildValues(updates) { [weak self] err, _ in
      guard let self else { return }
      if let err { self.errorMessage = err.localizedDescription; return }
      self.setupPresence()
      self.listenRoom()
    }
  }

  /// p2 전용: 리스너를 끊고 새 방에 입장
  func performRematchAsGuest(newCode: String, name: String) {
    // 1. 구 방 리스너 해제
    if let rr = roomRef, let h = roomHandle { rr.removeObserver(withHandle: h) }
    roomHandle = nil
    roomRef = nil

    // 2. 로컬 상태 초기화
    resetLocalGameState(keepPlayer: false)

    // 3. 새 방 입장 (기존 joinRoom 재사용)
    joinRoom(code: newCode, name: name)
  }

  /// 게임 상태만 초기화 (Firebase 삭제 없이)
  private func resetLocalGameState(keepPlayer: Bool) {
    commits        = []
    rounds         = [:]
    outcome        = nil
    currentTurn    = nil
    mySecret       = nil
    mySalt         = nil
    myCommitHash   = nil
    turnSecret     = nil
    rematchRequests    = []
    rematchNewRoomCode = nil
    players        = keepPlayer ? players : [:]
    errorMessage   = nil
  }

  // MARK: Commit / Reveal
  func commitMySecret(_ secret: String) {
    guard BaseballLogic.validate3UniqueDigits(secret) else {
      errorMessage = loc?.t("error.invalidSecret") ?? "Answer must be 3 unique digits."
      return
    }
    guard let rr = roomRef else { return }
    errorMessage = nil

    let salt = CryptoUtil.randomSalt()
    let hash = CryptoUtil.sha256Hex(secret + salt)

    mySecret = secret
    mySalt = salt
    myCommitHash = hash

    rr.child("commits").child(playerId).setValue([
      "hash": hash,
      "committedAt": ServerValue.timestamp()
    ])
  }

  func revealMySecret() {
    guard let rr = roomRef else { return }
    guard let secret = mySecret, let salt = mySalt else { return }

    rr.child("reveal").child(playerId).setValue([
      "secret": secret,
      "salt": salt
    ])
  }

  // MARK: Guess / Judge
  func submitGuess(_ guess: String) {
    guard status == "playing" else { return }
    guard BaseballLogic.validate3UniqueDigits(guess) else {
      errorMessage = loc?.t("error.invalidGuess") ?? "Guess must be 3 unique digits."
      return
    }

    if gameMode == "turn", let turn = currentTurn, turn != playerId {
      errorMessage = loc?.t("error.notYourTurn") ?? "It's your opponent's turn."
      return
    }

    errorMessage = nil
    guard let rr = roomRef else { return }

    let nextRound = (rounds.keys.max() ?? 0) + 1

    if gameMode == "turn" {
      // 턴제: guess + result + 턴 전환을 한번에 기록
      guard let secret = turnSecret else { return }
      let (s, b) = BaseballLogic.strikeBall(secret: secret, guess: guess)
      let opp = opponentId()

      var updates: [String: Any] = [
        "rounds/\(nextRound)/guessFrom/\(playerId)/value": guess,
        "rounds/\(nextRound)/guessFrom/\(playerId)/ts": ServerValue.timestamp(),
        "rounds/\(nextRound)/resultFor/\(playerId)/strike": s,
        "rounds/\(nextRound)/resultFor/\(playerId)/ball": b,
        "rounds/\(nextRound)/resultFor/\(playerId)/ts": ServerValue.timestamp(),
        "currentTurn": opp
      ]

      // 3S → 즉시 승리
      if s == 3 {
        updates["solvedAt/\(playerId)"] = ServerValue.timestamp()
      }

      rr.updateChildValues(updates)
    } else {
      // 동시대결: guess만 기록 (판정은 상대 클라이언트가 함)
      rr.child("rounds").child("\(nextRound)").child("guessFrom").child(playerId).setValue([
        "value": guess,
        "ts": ServerValue.timestamp()
      ])
    }
  }

  /// 동시대결 전용: 상대가 던진 guess를 내 secret으로 판정해서 resultFor[상대]에 기록
  func judgeOpponentIfNeeded() {
    guard gameMode == "simultaneous" else { return }  // 턴제는 서버 정답으로 자동 판정
    guard status == "playing" else { return }
    guard let rr = roomRef else { return }
    guard let secret = mySecret else { return }

    let opp = opponentId()
    for (round, rs) in rounds.sorted(by: { $0.key < $1.key }) {
      if let g = rs.guessFrom[opp], rs.resultFor[opp] == nil {
        let (s, b) = BaseballLogic.strikeBall(secret: secret, guess: g.value)

        rr.child("rounds").child("\(round)").child("resultFor").child(opp).setValue([
          "strike": s,
          "ball": b,
          "ts": ServerValue.timestamp()
        ])

        // if opponent solved my secret (3S), set solvedAt[opp]
        if s == 3 {
          rr.child("solvedAt").child(opp).setValue(ServerValue.timestamp())
        }
      }
    }
  }

  // MARK: Listen room
  private func listenRoom() {
    guard let rr = roomRef else { return }

    let expectedRoom = roomCode
    roomHandle = rr.observe(.value) { [weak self] snap in
      // Firebase 콜백은 nonisolated — @MainActor 프로퍼티 접근을 위해 Task로 dispatch
      Task { @MainActor [weak self] in
        guard let self else { return }
        // Stale callback guard: ignore if room changed since listener was set up
        guard self.roomCode == expectedRoom else { return }
        guard let data = snap.value as? [String: Any] else {
          return
        }

        self.status = data["status"] as? String ?? "lobby"
        self.gameMode = data["gameMode"] as? String ?? "simultaneous"
        self.hostId = data["hostId"] as? String ?? "p1"
        self.isPublic = data["isPublic"] as? Bool ?? false
        if let gc = data["groupCode"] as? String { self.groupCode = gc }

        if let ct = data["currentTurn"] as? String {
          self.currentTurn = ct
        } else {
          self.currentTurn = nil
        }

        // players parse
        self.players = Self.parsePlayers(data["players"] as? [String: Any] ?? [:])

        // commits parse (동시대결)
        self.commits = Self.parseCommits(data["commits"] as? [String: Any] ?? [:])

        // 턴제: 서버 정답 읽기
        if let ts = data["turnSecret"] as? String {
          self.turnSecret = ts
        }

        // rounds parse — Firebase가 숫자 키("1","2"...)를 NSArray로 변환할 수 있으므로 둘 다 처리
        let roundsDict: [String: Any]
        if let dict = data["rounds"] as? [String: Any] {
          roundsDict = dict
        } else if let arr = data["rounds"] as? [Any] {
          // NSArray → [String: Any] 변환 (index가 키)
          var converted: [String: Any] = [:]
          for (i, v) in arr.enumerated() {
            if !(v is NSNull) { converted["\(i)"] = v }
          }
          roundsDict = converted
        } else {
          roundsDict = [:]
        }
        self.rounds = Self.parseRounds(roundsDict)

        // outcome parse
        if let out = data["outcome"] as? [String: Any] {
          let parsed = OutcomeState(
            type: out["type"] as? String ?? "win",
            winnerId: out["winnerId"] as? String,
            reason: out["reason"] as? String
          )
          self.outcome = parsed
        } else {
          self.outcome = nil
        }

        // rematch parse
        if let rematchData = data["rematch"] as? [String: Any] {
          var reqs: Set<String> = []
          if rematchData["p1"] as? Bool == true { reqs.insert("p1") }
          if rematchData["p2"] as? Bool == true { reqs.insert("p2") }
          self.rematchRequests = reqs
          if let nc = rematchData["newRoomCode"] as? String,
             !nc.isEmpty, self.rematchNewRoomCode == nil {
            self.rematchNewRoomCode = nc
          }
        }

        // match context (league mode)
        self.matchId = data["matchId"] as? String
        self.matchGame = data["matchGame"] as? Int ?? 0
        self.level = data["level"] as? Int ?? 0
        if let aw = data["assignedWorker"] as? String {
          self.assignedWorkerId = aw
        }

        // start game when ready (host only)
        self.maybeStartGameIfReady(data)

        // disconnect forfeit
        self.maybeForfeitOnDisconnect(data)

        // decide outcome (win/draw)
        self.maybeDecideOutcome(data)

        // finished: verify commit-reveal if possible
        self.maybeVerifyCommitRevealAndInvalidate(data)
      }
    }
  }

  private func opponentId() -> String { playerId == "p1" ? "p2" : "p1" }

  private func maybeStartGameIfReady(_ data: [String: Any]) {
    guard let rr = roomRef else { return }

    let st = data["status"] as? String ?? "lobby"
    guard st == "lobby" else { return }

    let players = (data["players"] as? [String: Any]) ?? [:]
    let hasP1 = players["p1"] != nil
    let hasP2 = players["p2"] != nil

    if gameMode == "turn" {
      // 턴제: 두 플레이어 입장 즉시 게임 시작, 서버가 정답 생성
      if hasP1, hasP2 {
        let secret = BaseballLogic.randomSecret()
        rr.updateChildValues([
          "status": "playing",
          "currentTurn": "p1",
          "turnSecret": secret
        ])
      }
    } else {
      // 동시대결: 두 플레이어 + 양쪽 커밋 완료 시 시작
      let commits = (data["commits"] as? [String: Any]) ?? [:]
      let c1 = commits["p1"] != nil
      let c2 = commits["p2"] != nil

      if hasP1, hasP2, c1, c2 {
        rr.child("status").setValue("playing")
      }
    }
  }

  private func maybeForfeitOnDisconnect(_ data: [String: Any]) {
    guard status == "playing" else { return }
    guard outcome == nil else { return }

    let playersRaw = (data["players"] as? [String: Any]) ?? [:]
    let opp = opponentId()

    // opponent node removed => immediate forfeit win
    if playersRaw[opp] == nil {
      decideOutcomeTransaction(type: "forfeit", winnerId: playerId, reason: "disconnect")
      roomRef?.child("status").setValue("finished")
    }
  }

  private func maybeDecideOutcome(_ data: [String: Any]) {
    guard (status == "playing" || status == "finished") else { return }
    guard outcome == nil else { return }
    guard let rr = roomRef else { return }

    let solvedAt = (data["solvedAt"] as? [String: Any]) ?? [:]
    let t1 = Self.toInt64(solvedAt["p1"])
    let t2 = Self.toInt64(solvedAt["p2"])

    if gameMode == "turn" {
      // 턴제: 먼저 맞춘 사람이 즉시 승리 (draw window 없음)
      if let _ = t1 {
        decideOutcomeTransaction(type: "win", winnerId: "p1", reason: "solved")
        rr.child("status").setValue("finished")
        return
      }
      if let _ = t2 {
        decideOutcomeTransaction(type: "win", winnerId: "p2", reason: "solved")
        rr.child("status").setValue("finished")
        return
      }
    } else {
      // 동시대결: draw window 적용
      // both solved: draw window
      if let t1, let t2 {
        let diff = abs(t1 - t2)
        if diff <= DRAW_WINDOW_MS {
          decideOutcomeTransaction(type: "draw", winnerId: nil, reason: "time")
        } else {
          let winner = (t1 < t2) ? "p1" : "p2"
          decideOutcomeTransaction(type: "win", winnerId: winner, reason: "time")
        }
        rr.child("status").setValue("finished")
        return
      }

      // one solved: wait DRAW_WINDOW then win
      if let t1, t2 == nil {
        if serverNowMs() - t1 > DRAW_WINDOW_MS {
          decideOutcomeTransaction(type: "win", winnerId: "p1", reason: "time")
          rr.child("status").setValue("finished")
        }
        return
      }
      if let t2, t1 == nil {
        if serverNowMs() - t2 > DRAW_WINDOW_MS {
          decideOutcomeTransaction(type: "win", winnerId: "p2", reason: "time")
          rr.child("status").setValue("finished")
        }
        return
      }
    }
  }

  /// 동시대결 전용: finished 상태에서 reveal이 둘 다 있으면 커밋 해시 검증.
  /// mismatch 있으면 "invalid" 또는 "forfeit" 처리 (여기서는 mismatch 플레이어가 패배)
  private func maybeVerifyCommitRevealAndInvalidate(_ data: [String: Any]) {
    guard gameMode == "simultaneous" else { return }  // 턴제는 서버 정답이므로 검증 불필요
    guard status == "finished" else { return }
    guard let rr = roomRef else { return }

    // 이미 invalid/forfeit 같은 결과가 확정됐으면 스킵
    if let out = outcome, out.type == "invalid" || (out.type == "forfeit" && out.reason == "hash_mismatch") {
      return
    }

    guard let commitsRaw = data["commits"] as? [String: Any],
          let revealRaw = data["reveal"] as? [String: Any] else { return }

    // 둘 다 reveal 되어야 검증 시작
    guard revealRaw["p1"] != nil, revealRaw["p2"] != nil else { return }

    func commitHash(_ pid: String) -> String? {
      (commitsRaw[pid] as? [String: Any])?["hash"] as? String
    }
    func revealPair(_ pid: String) -> (secret: String, salt: String)? {
      guard let d = revealRaw[pid] as? [String: Any],
            let s = d["secret"] as? String,
            let salt = d["salt"] as? String else { return nil }
      return (s, salt)
    }

    let pids = ["p1", "p2"]
    for pid in pids {
      guard let cHash = commitHash(pid),
            let pair = revealPair(pid) else { return }

      // reveal validation
      guard BaseballLogic.validate3UniqueDigits(pair.secret) else {
        // invalid secret format => pid loses
        let winner = (pid == "p1") ? "p2" : "p1"
        decideOutcomeTransaction(type: "forfeit", winnerId: winner, reason: "hash_mismatch")
        rr.child("status").setValue("finished")
        return
      }

      let computed = CryptoUtil.sha256Hex(pair.secret + pair.salt)
      if computed != cHash {
        let winner = (pid == "p1") ? "p2" : "p1"
        decideOutcomeTransaction(type: "forfeit", winnerId: winner, reason: "hash_mismatch")
        rr.child("status").setValue("finished")
        return
      }
    }
    // all good -> no action (결과가 win/draw로 이미 있을 수 있고, 없다면 유지)
  }

  private func decideOutcomeTransaction(type: String, winnerId: String?, reason: String) {
    guard let rr = roomRef else { return }
    let outRef = rr.child("outcome")
    outRef.runTransactionBlock { current in
      if let _ = current.value as? [String: Any] {
        return TransactionResult.abort()
      }
      var v: [String: Any] = [
        "type": type,
        "reason": reason,
        "decidedAt": ServerValue.timestamp()
      ]
      if let winnerId { v["winnerId"] = winnerId }
      current.value = v
      return TransactionResult.success(withValue: current)
    } andCompletionBlock: { _, _, _ in }
  }

  // MARK: Public Rooms

  func listenPublicRooms(groupCode: String) {
    stopPublicRoomsListener()
    let group = groupCode.uppercased()
    let ref = db.child("publicRooms").child(group)
    publicRoomsRef = ref

    publicRoomsHandle = ref.observe(.value) { [weak self] snap in
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard let dict = snap.value as? [String: Any] else {
          self.publicRooms = []
          return
        }
        var entries: [PublicRoomEntry] = []
        for (roomCode, value) in dict {
          guard let d = value as? [String: Any] else { continue }
          let pc = d["playerCount"] as? Int ?? 1
          guard pc < 2 else { continue }
          entries.append(PublicRoomEntry(
            roomCode: roomCode,
            hostName: d["hostName"] as? String ?? "???",
            gameMode: d["gameMode"] as? String ?? "simultaneous",
            groupCode: group,
            createdAt: Self.toInt64(d["createdAt"]),
            playerCount: pc
          ))
        }
        entries.sort { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
        self.publicRooms = entries
      }
    }
  }

  func listenAllPublicRooms() {
    stopPublicRoomsListener()
    let ref = db.child("publicRooms")
    publicRoomsRef = ref

    publicRoomsHandle = ref.observe(.value) { [weak self] snap in
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard let groups = snap.value as? [String: Any] else {
          self.publicRooms = []
          return
        }
        var entries: [PublicRoomEntry] = []
        for (groupCode, groupValue) in groups {
          guard let rooms = groupValue as? [String: Any] else { continue }
          for (roomCode, roomValue) in rooms {
            guard let d = roomValue as? [String: Any] else { continue }
            let pc = d["playerCount"] as? Int ?? 1
            guard pc < 2 else { continue }
            entries.append(PublicRoomEntry(
              roomCode: roomCode,
              hostName: d["hostName"] as? String ?? "???",
              gameMode: d["gameMode"] as? String ?? "simultaneous",
              groupCode: groupCode,
              createdAt: Self.toInt64(d["createdAt"]),
              playerCount: pc
            ))
          }
        }
        entries.sort { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
        self.publicRooms = entries
      }
    }
  }

  func stopPublicRoomsListener() {
    if let ref = publicRoomsRef, let handle = publicRoomsHandle {
      ref.removeObserver(withHandle: handle)
    }
    publicRoomsRef = nil
    publicRoomsHandle = nil
    publicRooms = []
  }

  func fetchAvailableGroups() {
    db.child("publicRooms").observeSingleEvent(of: .value) { [weak self] snap in
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard let groups = snap.value as? [String: Any] else {
          self.availableGroups = []
          return
        }
        var entries: [GroupEntry] = []
        for (groupCode, groupValue) in groups {
          if let rooms = groupValue as? [String: Any] {
            let joinableCount = rooms.values.compactMap { $0 as? [String: Any] }
              .filter { ($0["playerCount"] as? Int ?? 1) < 2 }
              .count
            if joinableCount > 0 {
              entries.append(GroupEntry(groupCode: groupCode, roomCount: joinableCount))
            }
          }
        }
        entries.sort { $0.groupCode < $1.groupCode }
        self.availableGroups = entries
      }
    }
  }

  // MARK: Static parsing
  private static func parsePlayers(_ raw: [String: Any]) -> [String: PlayerInfo] {
    var out: [String: PlayerInfo] = [:]
    for pid in ["p1", "p2"] {
      if let d = raw[pid] as? [String: Any] {
        let name = d["name"] as? String ?? pid
        let connected = d["connected"] as? Bool ?? true
        out[pid] = PlayerInfo(name: name, connected: connected)
      }
    }
    return out
  }

  private static func parseCommits(_ raw: [String: Any]) -> Set<String> {
    var s: Set<String> = []
    for pid in ["p1", "p2"] {
      if raw[pid] != nil { s.insert(pid) }
    }
    return s
  }

  private static func parseRounds(_ raw: [String: Any]) -> [Int: RoundState] {
    var result: [Int: RoundState] = [:]
    for (k, v) in raw {
      guard let round = Int(k), let d = v as? [String: Any] else { continue }
      var rs = RoundState()

      if let gf = d["guessFrom"] as? [String: Any] {
        for (pid, gv) in gf {
          if let g = gv as? [String: Any],
             let value = g["value"] as? String {
            let ts = toInt64(g["ts"])
            rs.guessFrom[pid] = Guess(value: value, ts: ts)
          }
        }
      }

      if let rf = d["resultFor"] as? [String: Any] {
        for (pid, rv) in rf {
          if let r = rv as? [String: Any],
             let strike = r["strike"] as? Int,
             let ball = r["ball"] as? Int {
            let ts = toInt64(r["ts"])
            rs.resultFor[pid] = Result(strike: strike, ball: ball, ts: ts)
          }
        }
      }

      result[round] = rs
    }
    return result
  }

  private static func toInt64(_ any: Any?) -> Int64? {
    if let v = any as? Int64 { return v }
    if let v = any as? Int { return Int64(v) }
    if let v = any as? Double { return Int64(v) }
    return nil
  }
}
