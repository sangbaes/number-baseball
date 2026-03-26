# Number Baseball - iOS App Dev Note

## 프로젝트 개요
HTML 기반 숫자야구(Number Baseball) 멀티플레이어 게임을 iOS 네이티브 앱으로 전환한 프로젝트.
Firebase Realtime Database를 백엔드로 사용하며, 솔로/동시대결/턴제/CPU대전 4가지 모드를 지원한다.

## 기술 스택
- **UI**: SwiftUI (iOS 17+)
- **Backend**: Firebase Realtime Database
- **인증**: Firebase Anonymous Auth
- **CPU 대전**: Python 봇 워커 (알고리즘 전략 기반, LLM 미사용)
- **빌드**: Xcode 17, SPM (Firebase SDK 12.9.0)
- **Firebase 프로젝트**: `number-baseball-28392`
- **DB URL**: `https://number-baseball-28392-default-rtdb.firebaseio.com`

## Firebase Rules
```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "publicRooms": {
      ".read": "auth != null",
      "$groupCode": {
        "$roomId": {
          ".write": "auth != null"
        }
      }
    },
    "botWorkers": {
      ".read": "auth != null",
      "$workerId": {
        ".write": "auth != null"
      }
    },
    "matches": {
      ".indexOn": ["botWorkerId"],
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "playerProgress": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

---

## 파일 구조

```
number-baseball/
├── DEV_NOTE.md
├── REFACTOR-PROMPT.md              # 방식 A 리팩토링 설계 문서
├── run-league-bots.sh              # CPU 대전 봇 런처 (9워커)
├── *.html                           # 원본 HTML 버전 (참고용)
├── worker/                          # Python CPU 봇 워커
│   ├── __main__.py                  # 워커 진입점 (WorkerPool + GameEngine)
│   ├── config.py                    # BotConfig 데이터클래스 + YAML 로더
│   ├── config-level1~5.yaml         # 5단계 레벨별 설정 파일
│   ├── game_engine.py               # 봇 FSM (IDLE→WAITING→PLAYING→FINISHED)
│   ├── room_manager.py              # WorkerPool (stale assignment/room 정리)
│   ├── presence.py                  # PresenceManager (heartbeat 기반 connected 유지)
│   ├── firebase_client.py           # Firebase Admin SDK 초기화
│   ├── baseball.py                  # 야구 게임 로직 (판정, 후보 관리)
│   └── strategy/
│       ├── __init__.py              # get_strategy() 팩토리
│       ├── base.py                  # Strategy 베이스 클래스
│       ├── random_strat.py          # 랜덤 전략
│       ├── elimination.py           # 소거법 전략
│       ├── entropy.py               # 엔트로피 전략
│       └── noisy.py                 # NoisyStrategy 데코레이터 (에러율 주입)
└── number-baseball/
    └── number-baseball/
        ├── YourApp.swift             # @main, Firebase 초기화, AuthGate (익명 인증 대기)
        ├── MainMenuView.swift        # 메인 메뉴
        ├── MultiplayerHomeView.swift # 멀티플레이 홈 (CPU 대전 진입)
        ├── LeagueHomeView.swift      # CPU 대전 5단계 레벨 선택 (botWorkers 기반 봇 카운트)
        ├── ProgressionManager.swift  # Firebase 진행도 + botWorkers 풀에서 워커 탐색/배정
        ├── SoloGameView.swift        # 솔로 모드
        ├── CreateRoomView.swift      # 방 생성 폼
        ├── JoinRoomView.swift        # 방 입장 폼
        ├── RoomFlowView.swift        # 멀티플레이 게임 화면 (리그 결과 오버레이 포함)
        ├── RoomService.swift         # Firebase 방 서비스 (createBotRoom 포함)
        ├── Models.swift              # 데이터 모델 (LeagueLevel 등)
        ├── BaseballLogic.swift       # 게임 로직 유틸
        ├── NumberBaseballLogic.swift  # 솔로 모드 전용 로직
        ├── CryptoUtil.swift          # SHA256 해싱
        ├── LocalizationManager.swift # 4개 언어 지원 (en/ko/ja/es)
        └── GoogleService-Info.plist  # Firebase 설정
```

### 삭제된 파일 (히스토리)
- `ContentView.swift` — 초기 기본 뷰, MainMenuView로 대체
- `number_baseballApp.swift` — YourApp.swift로 대체
- `MultiplayerGameView.swift` — RoomFlowView.swift에 통합
- `config-easy/medium/hard.yaml` — 3단계 → 5단계 리그 전환으로 삭제
- `MatchLobbyView.swift` — 네비게이션 단순화로 삭제
- `MatchResultView.swift` — RoomFlowView 내 LeagueResultOverlay로 대체
- `match_engine.py` — 방식 A 리팩토링으로 삭제 (MatchEngine 제거, GameEngine이 직접 처리)
- `ollama_chat.py` — CPU 대전 전환으로 삭제 (LLM 채팅 제거, 알고리즘 전략만 사용)

---

## 게임 모드별 상세

### 1. 솔로 모드 (`SoloGameView`)
- `NumberBaseballLogic.generateAnswer()`로 랜덤 3자리 정답 생성
- 플레이어가 반복 추측, 스트라이크/볼 결과 표시
- 컴팩트 상단 바 (시도횟수 + 입력 + 메뉴 in HStack)
- 키보드 toolbar에 "추측하기" 버튼 배치
- 메뉴(ellipsis)에 새 게임/정답 보기 기능

### 2. 동시대결 모드 (`simultaneous`)
**게임 흐름:**
1. 방 생성 → 상대 입장 대기
2. **커밋 단계**: 각자 3자리 정답 설정 → SHA256(secret+salt) 해시 커밋
3. 양쪽 커밋 완료 → 게임 자동 시작 (호스트가 status="playing" 전환)
4. 동시에 추측 입력, 상대 클라이언트가 자기 정답 기준으로 판정
5. 먼저 3S 맞추면 승리 (1.5초 draw window 내 동시 정답 시 무승부)

**핵심 메커니즘:**
- **커밋-리빌 안티치트**: 정답 변경 방지를 위해 SHA256 해시 선 커밋
- **판정 주체**: 각 클라이언트가 상대의 추측을 자기 정답으로 판정 (`judgeOpponentIfNeeded`)
- **Draw Window**: `DRAW_WINDOW_MS = 1500` (1.5초) 내 동시 정답 시 무승부

### 3. 턴제 모드 (`turn`)
**게임 흐름:**
1. 방 생성 → 상대 입장 대기
2. 두 명 입장 즉시 게임 시작 (커밋 단계 없음)
3. **서버(호스트)가 랜덤 정답 생성** → Firebase `turnSecret`에 저장
4. p1부터 교대로 추측, 서로의 결과를 보면서 추론
5. 먼저 3S 맞추면 즉시 승리 (draw window 없음)

**핵심 메커니즘:**
- **서버 정답**: `BaseballLogic.randomSecret()`로 생성, 양쪽 모두 같은 정답을 맞춤
- **즉시 판정**: 추측 제출 시 guess + result + 턴 전환을 `updateChildValues`로 원자적 기록
- **턴 전환**: 제출 후 자동으로 `currentTurn`이 상대로 전환

### 4. CPU 대전 모드 (League) — 방식 A (단순화)

5단계 CPU 봇과 단판제 게임을 진행하는 싱글플레이어 리그 시스템.
각 단계를 클리어하면 다음 단계의 키를 획득하여 잠금 해제한다.

#### 핵심 설계 원칙 (방식 A)

**책임 분리:**
- **워커**: `botWorkers/{workerId}` 풀에 등록하고, 배정된 방을 listen하여 게임만 플레이
- **iOS**: 방 생성, 워커 배정, 방 정리를 **전부** 담당
- 워커는 **절대** 방을 생성하거나 정리하지 않음
- 워커는 **절대** `publicRooms/`를 터치하지 않음

**이점:**
- 좀비 방 문제 해결 (iOS가 방 lifecycle 전체를 소유)
- Python Admin SDK의 `onDisconnect` 미지원 문제 회피
- 워커-iOS 간 책임 충돌 제거

#### 레벨 구성

| Level | 이름 | 전략 | 에러율 | 응답 딜레이 | 그룹코드 |
|-------|------|------|--------|------------|---------|
| 1 | Beginner | random | 0% | 3.5s | L01 |
| 2 | Intermediate | elimination | 40% | 3.0s | L02 |
| 3 | Advanced | elimination | 0% | 2.0s | L03 |
| 4 | Expert | entropy | 15% | 1.5s | L04 |
| 5 | Master | entropy | 0% | 1.0s | L05 |

- **random**: 무작위 추측 (가장 약함)
- **elimination**: 이전 결과로 후보군을 소거 (중급)
- **entropy**: 정보 엔트로피 최대화 추측 (최강)
- **NoisyStrategy**: 데코레이터 패턴으로 일정 확률(`error_rate`)에 랜덤 추측 주입

#### 리그 게임 흐름 (방식 A)

```
[iOS] LeagueHomeView                    [Worker] GameEngine
       │                                       │
       │                           _do_idle(): botWorkers/{id} 등록
       │                           status="idle", config={name,level,groupCode}
       │                                       │
       │                           _do_waiting(): assignment 리스너 대기
       │                                       │
  레벨 선택 → ProgressionManager               │
       │    .findAndJoinBotRoom()               │
       │         │                              │
       │    botWorkers/ 쿼리                    │
       │    idle 워커 중 groupCode 매칭         │
       │         │                              │
       │    RoomService.createBotRoom()         │
       │    ┌─ rooms/{code} 생성               │
       │    ├─ players/p1 (봇) 등록             │
       │    ├─ players/p2 (사람) 등록           │
       │    ├─ botWorkers/{id}/assignment 기록  │
       │    └─ botWorkers/{id}/status="playing" │
       │         │                              │
       │    (atomic multi-path update)  ───────→ assignment 이벤트 수신
       │         │                              │
       │    setupPresence()             _do_waiting(): room 리스너 시작
       │    listenRoom()                presence heartbeat 시작
       │         │                              │
       │    maybeStartGameIfReady()             │
       │    ├─ turnSecret 생성                  │
       │    └─ status="playing"         ───────→ _do_playing(): 게임 루프
       │         │                              │
       │    ← 턴 교대 게임 진행 →                │
       │         │                              │
       │    maybeDecideOutcome()                │
       │    outcome 설정             ──────────→ outcome 감지 → FINISHED
       │         │                              │
       │    RoomFlowView:                       │
       │    LeagueResultOverlay 표시    _do_finished():
       │         │                      _safe_cleanup()
       │    handleNextLevel() 또는       botWorkers/{id} → idle
       │    handleRetry() 또는                  │
       │    handleBackToLeague()        _do_idle(): 다음 게임 대기
       │         │                              │
       │    leaveRoom():                        │
       │    ├─ botWorkers/{id} → idle           │
       │    ├─ rooms/{code} 삭제                │
       │    └─ 로컬 상태 리셋                    │
```

#### 봇 워커 아키텍처 (Python — 방식 A)

```
__main__.py
  ├─ Config.load(yaml)       # 레벨별 YAML 설정
  ├─ WorkerPool              # stale assignment/room 정리
  │    ├─ cleanup_stale_assignment()  # 이전 크래시의 잔여 assignment 제거
  │    └─ cleanup_stale_rooms()       # legacy: 구 publicRooms 엔트리 정리
  │
  └─ GameEngine.run()        # 메인 루프 (무한반복)
       ├─ _do_idle()
       │    ├─ botWorkers/{id} 등록 (status=idle, config)
       │    └─ assignment 리스너 시작
       ├─ _do_waiting()
       │    ├─ assignment_queue 대기 (iOS가 배정할 때까지)
       │    ├─ assignment 수신 → room 리스너 시작
       │    └─ PresenceManager 시작 (heartbeat)
       ├─ _do_playing()
       │    ├─ room_queue에서 이벤트 수신 → _apply_event()
       │    ├─ outcome 감지 → FINISHED
       │    ├─ p2 disconnect 감지 (Firebase .get() 재확인) → FINISHED
       │    └─ currentTurn == "p1"이면 _submit_guess()
       └─ _do_finished()
            ├─ _safe_cleanup() (리스너/presence 정리)
            ├─ botWorkers/{id} → idle
            └─ restart_delay 후 IDLE로 복귀
```

- **워커 ID**: `{group_code}-{hostname}-{instance}` 형식으로 자동 생성
- **이벤트 큐 분리**: `_assignment_queue` + `_room_queue` (혼선 방지)
- **Stale 정리**: 시작 시 이전 실행의 잔여 assignment 자동 정리
- **독립 실행**: 각 워커는 무상태(stateless), 동일 레벨에 여러 인스턴스 병렬 실행 가능
- **이중 추론 방지**: 3중 가드 (currentTurn 확인 → 기존 라운드 guess 존재 확인 → delay 후 재확인)

#### Firebase 데이터 구조 (방식 A)

```
botWorkers/
  {workerId}/                          # e.g. "L01-Main-Frame-1"
    status: "idle" | "playing"
    config/
      name: "CPU-Beginner"
      level: 1
      groupCode: "L01"
    assignment/                        # iOS가 기록, 워커가 읽음
      roomCode: "2LEC2"
      assignedAt: <timestamp>
    updatedAt: <timestamp>

rooms/
  {roomCode}/
    status: "lobby" | "playing" | "finished"
    gameMode: "turn"
    hostId: "p1"
    createdAt: <timestamp>
    currentTurn: "p1" | "p2"
    turnSecret: "482"                  # 서버 정답
    groupCode: "L01"                   # 리그 레벨 그룹
    level: 1
    workerId: "L01-Main-Frame-1"       # 배정된 워커
    assignedWorker: "L01-Main-Frame-1"
    players/
      p1/                              # 봇 (iOS가 대리 등록)
        name: "CPU-Beginner"
        joinedAt: <timestamp>
        connected: true                # 워커 heartbeat로 유지
      p2/                              # 사람
        name: "Kim"
        uid: "firebase-anonymous-uid"
        joinedAt: <timestamp>
        connected: true                # iOS onDisconnect로 관리
    rounds/
      1/
        guessFrom/
          p1/
            value: "953"
            ts: <timestamp>
        resultFor/
          p1/
            strike: 0
            ball: 1
            ts: <timestamp>
    solvedAt/
      p2: <timestamp>                 # p2가 3S 달성한 시각
    outcome/
      type: "win" | "draw" | "forfeit"
      winnerId: "p2"
      reason: "solved" | "disconnect"
      decidedAt: <timestamp>
playerProgress/
  {uid}/
    unlockedLevels: [1, 2]
    keys/
      L01_KEY: true
    matchHistory/
      {matchId}/
        level: 1
        result: "win"
        completedAt: <timestamp>
    updatedAt: <timestamp>

publicRooms/                           # PvP 전용 (리그 미사용)
  {groupCode}/
    {roomCode}/
      hostName: "Player1"
      gameMode: "turn"
      createdAt: <timestamp>
      playerCount: 1
```

#### 진행도 관리 (ProgressionManager)

- `@Published unlockedLevels: Set<Int>` — 해금된 레벨 목록
- `syncFromFirebase()` — 앱 시작 시 `playerProgress/{uid}` 읽어서 로컬 동기화 (UserDefaults 캐시)
- `findAndJoinBotRoom()` — `botWorkers/`에서 idle 워커 탐색 → `RoomService.createBotRoom()` 호출
- `grantKey(level:roomCode:)` — 승리 시 다음 레벨 키 부여
- `recordLoss(level:roomCode:)` — 패배 기록

#### 리그 결과 처리 (RoomFlowView)

게임 종료 후 `LeagueResultOverlay`가 인라인 오버레이로 표시:
- **승리**: "Next Level" 버튼 → `handleNextLevel()` (키 부여 → leaveRoom → 다음 레벨 방 생성)
- **패배**: "Retry" 버튼 → `handleRetry()` (패배 기록 → leaveRoom → 같은 레벨 방 생성)
- **돌아가기**: "Back to League" 버튼 → `handleBackToLeague()` (leaveRoom → dismiss)

#### 워커 실행 방법

```bash
# 전체 9워커 시작 (Level 1×3, 2×2, 3×2, 4×1, 5×1)
./run-league-bots.sh

# 중지 / 상태 확인
./run-league-bots.sh stop
./run-league-bots.sh status

# 개별 워커 실행 (디버깅용)
python3 -m worker worker/config-level1.yaml
python3 -m worker worker/config-level1.yaml --instance 2
```

---

## UI 구조

### 히스토리 (Side-by-Side)
동시대결과 턴제 모두 동일한 레이아웃 사용:
```
┌─────────────────────────────────────┐
│  나 (3)       R     상대 (2)        │  ← 컬럼 헤더
├─────────────────────────────────────┤
│  456  1S 1B   3     ···            │  ← 최신순
│  ───          2     321  OUT       │
│  123  1S      1     ───            │
└─────────────────────────────────────┘
```
- **동시대결**: 순번별 짝짓기 (나의 1번째 vs 상대 1번째)
- **턴제**: 라운드별 표시 (턴 소유자만 표시, 나머지는 "—")

### 인풋 바
- 키보드 toolbar에 제출 버튼 배치
- 턴제에서 상대 턴일 때: "상대 턴 대기중..." 텍스트로 교체
- `BaseballLogic.filterUniqueDigits`로 실시간 중복 숫자 필터링

---

## 해결한 주요 버그

### 1. Firebase NSArray 자동 변환
- **문제**: `data["rounds"] as? [String: Any]` → nil 반환
- **원인**: Firebase가 순차 숫자 키("1","2"...)를 자동으로 NSArray로 변환
- **해결**: `[Any]`(NSArray) 타입도 처리하는 fallback 추가
```swift
if let dict = data["rounds"] as? [String: Any] {
  roundsDict = dict
} else if let arr = data["rounds"] as? [Any] {
  var converted: [String: Any] = [:]
  for (i, v) in arr.enumerated() {
    if !(v is NSNull) { converted["\(i)"] = v }
  }
  roundsDict = converted
}
```

### 2. @MainActor isolation
- **문제**: Firebase `observe(.value)` 콜백이 nonisolated → @MainActor 프로퍼티 접근 불가
- **해결**: 모든 Firebase 콜백을 `Task { @MainActor [weak self] in ... }`로 래핑

### 3. Firebase Rules
- **문제**: `rooms/.read/.write` 패턴으로는 하위 경로 접근 불가
- **해결**: `rooms/$code/.read/.write` 와일드카드 패턴으로 변경

### 4. 중복 숫자 입력
- **문제**: "111" 같은 중복 숫자 입력 가능
- **해결**: `BaseballLogic.filterUniqueDigits` → TextField onChange에서 실시간 필터링

### 5. 봇 워커 "Opponent disconnected" 오탐 (방식 A 전환 후)
- **문제**: 봇이 첫 추측 후 ~4초만에 "Opponent (p2) disconnected — ending game" 로그와 함께 게임 종료
- **원인**: assignment 리스너와 room 리스너가 동일한 `_event_queue`를 공유. assignment 리스너를 `close()`해도 큐에 이미 들어간 stale assignment 이벤트(`{"roomCode": "...", "assignedAt": ...}`)가 `_apply_event(path="/")` 에서 `_room_data`를 통째로 덮어씀 → `players` 키 소실 → p2 없음으로 오판
- **해결**:
  1. 이벤트 큐를 `_assignment_queue` + `_room_queue`로 분리
  2. `_do_playing`에서 마지막 이벤트만 사용하던 것을 모든 이벤트를 순서대로 적용하도록 변경
  3. p2 disconnect 판정 전 `_drain_and_sync()`로 Firebase에서 직접 재확인

### 6. Firebase multi-path update에서 nested dict 에러
- **문제**: `.update()`에 `{".sv": "timestamp"}` 포함된 중첩 객체 전달 시 400 Bad Request
- **해결**: 모든 경로를 flat하게 펼쳐서 해결: `"rooms/{code}/players/p1/name": name`

### 7. Auth 타이밍 (permission_denied)
- **문제**: `signInAnonymously()`가 비동기인데 완료 전에 DB 리스너 등록
- **해결**: `AuthGate` ObservableObject 도입: 인증 완료까지 ProgressView 표시

---

## 참고사항
- `NumberBaseballLogic.swift`는 솔로 모드 전용, `BaseballLogic.swift`는 공용 — 추후 통합 고려
- HTML 원본은 프로젝트 루트에 참고용으로 보존
- 봇 워커는 `firebase-admin` Python SDK 사용 (Admin 권한, Rules 우회)
- Python Admin SDK는 `onDisconnect()`를 지원하지 않음 → 대신 PresenceManager heartbeat 사용 (15초 간격)
- `run-league-bots.sh`는 터미널에서 직접 실행해야 함 (IDE 세션에서는 프로세스 유지 안됨)

## 남은 작업
- [ ] 봇 서버 배포 (현재 로컬 실행만 지원)
- [ ] 봇 크래시 시 iOS 측 타임아웃 처리 (워커 할당 후 무응답 대응)
