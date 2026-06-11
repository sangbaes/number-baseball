# DEV_NOTES

## 2026-06-11 — 다크 리스타일 + 사용설명서 + 웹 멀티플레이 활성화

iOS 앱과 같은 GA4 속성으로 통합된 이후, 같은 날 세 가지 큰 작업을 묶어 진행.

### 완료한 작업 1: 사용설명서 페이지 + sinbiroum 다크 톤 전면 리스타일
- `web/src/js/analytics.js`에 `howToPlayOpened()` 헬퍼 추가 (iOS 동일)
- 사용설명서 페이지 신규 — iOS `HowToPlayView` 1:1 미러
  - 4섹션: 🎯 목표 / 💡 피드백 (S·B·OUT 배지) / 📋 규칙 (번호 원형) / 🧩 예시 (색 dot으로 단서 수준 표현)
  - `help.*` 17개 키 한/영 추가 ([i18n.js](web/src/js/i18n.js))
  - 진입점: 모드 선택 하단 "ℹ️ 게임 방법" subtle 텍스트 링크
  - 분석: `GameAnalytics.howToPlayOpened()`
- `main.css` 전면 재작성 (sinbiroum.com 메인과 디자인 토큰 일치)
  - 컬러: `--bg-deep #04091A` / `--bg-card #0C1530` / `--cyan #3DFFD0` / `--gold #E8B84B`
  - 폰트: Cormorant Garamond (제목·점수) + Syne (버튼·라벨) + JetBrains Mono (숫자·태그)
  - 시그니처: 48px 시안 그리드 BG, 블러 글로우 오브, 12px 라운드, fadeInUp 진입 애니메이션, hover translateY(-2~3px)
  - 플레이어 카드: 내 카드 시안 그라데이션, 상대/CPU 골드 그라데이션
- 캐시 버스터 v4.4 → v4.5

### 완료한 작업 2: 웹 멀티플레이 활성화 (Phase 3 부분 — `/webRooms` 격리 방식)
**진단**: RTDB 규칙이 `auth != null` 요구하는데 웹은 익명 로그인이 없어서 v3.1 이후 멀티플레이 무동작이었음. 또한 iOS는 commit-reveal로 각자 비밀, 웹은 공유 비밀이라 스키마 자체가 호환 안 됨 (자세한 비교는 conversation history).

**선택한 방향**: 풀 인터옵(B 풀버전)은 6-10시간 작업이라 후속으로 미루고, B' (웹 전용 네임스페이스로 격리) 채택. 1-2시간.

- `database.rules.json`에 `/webRooms` 블록 추가 (`auth != null`만 요구, iOS의 `/rooms`와 완전 분리)
- `index.html`: `firebase-auth-compat.js` SDK 로드
- `firebase-config.js`: `firebase.auth()` 초기화, `signInAnonymously()` 호출 + `authReady` 글로벌 Promise 노출
  - 패턴: 첫 `onAuthStateChanged` 콜백이 user면 캐시 세션 복원 → resolve, null이면 signInAnonymously 트리거. `signInTriggered` 가드로 중복 호출 방지
- `multiplayer.js`: `rooms/` → `webRooms/` (7곳), `createRoom`/`joinRoom`을 async로 만들고 `await authReady`로 인증 대기
- `i18n.js`: `errorAuth` 키 한/영 추가
- 캐시 버스터 v4.5 → v4.7 (배포 중 한 번 더 콘텐츠 변경으로 4.6 건너뜀)

### sinbiroum-web 별도 레포 변경 (수동 커밋·배포 필요)
- `sinbiroum-web/firebase.json`의 `/baseball/**` CSP `connect-src`에 두 호스트 추가:
  - `https://identitytoolkit.googleapis.com` (익명 가입)
  - `https://securetoken.googleapis.com` (토큰 갱신)
- 적용 후 `firebase deploy --only hosting:sinbiroum-v1` 실행함

### 배포 시 만난 문제 (참고)
- **`.firebaserc` gitignored라 신규 클론 후 누락** → `{"projects":{"default":"number-baseball-28392"}}` 다시 생성
- **Firebase CLI 멀티 계정**: `sangbaekim@sinbiroum.com`(sinbiroum-v1 호스팅)과 `rabiteye21@gmail.com`(number-baseball-28392 RTDB)이 다른 계정. `firebase login:add`로 보조 계정 추가, 명령마다 `--account rabiteye21@gmail.com` 플래그 명시

### 부수 산출물
- `qr-baseball.png` — https://sinbiroum.com/baseball/ QR (600×600, ECC-H)
- `Number-Baseball-Intro.docx` — A4 세로 1페이지 게임 소개서 (QR + 사용설명서 내용). LinkedIn/오프라인 공유용

### 알려진 제약
- 웹 유저끼리만 매칭 가능 (`/webRooms`). iOS 유저는 자신의 `/rooms`에서만 보임.
- iOS ↔ 웹 풀 인터옵은 commit-reveal 프로토콜 웹 포팅 필요 — 후속 작업

### 다음에 할 일 (변경 없음 + 추가)
- 기존: Phase 3 잔여 (키 TTL), Phase 4 (리더보드 — 솔로 먼저)
- 신규: iOS ↔ 웹 풀 인터옵 (수요 확인 후, commit-reveal 웹 포팅)

---

## 2026-06-11 — 웹 버전 Firebase Analytics 통합

### 문제
- iOS 앱은 GA4 대시보드(`p518960667`, measurementId `G-K7Y19FJ5N7`)에 사용자/이벤트가 정상 집계됐는데, 웹은 같은 대시보드에 안 잡혔다.
- 원인: 웹은 독립 gtag.js로 **별개 GA4 속성(`G-4YCRZYFNX4`)** 으로 데이터를 보내고 있었음. `firebase-config.js`에 `measurementId: "G-K7Y19FJ5N7"`가 있었지만 `firebase-analytics-compat.js`를 로드하지 않아 죽은 값이었음.

### 완료한 작업 — iOS와 동일한 GA4 속성으로 통합 (commit `5103e1d`)
- `web/src/js/analytics.js` 신규 — iOS `AnalyticsService.swift`의 1:1 미러
  - 12개 헬퍼: `screenView`, `languageChanged`, `gameModeSelected`, `roomCreated`, `roomJoined`, `roomLeft`, `guessSubmitted`, `gameWon`, `gameLost`, `gameDraw`, `soloGameStarted`, `soloGameWon`, `soloGameLost`
  - 이벤트명·파라미터 키 모두 iOS와 동일 → GA4에서 플랫폼 통합 리포트 가능
- `index.html`: 독립 gtag 스니펫 제거 → `firebase-analytics-compat.js` 추가, 캐시 버스터 v4.3 → v4.4
- `firebase-config.js`: `firebase.analytics()` 호출 → `measurementId`(`G-K7Y19FJ5N7`) 실제 활성화
- 후킹 지점 (iOS와 동일):
  - `i18n.js`: `setLanguage` → `language_changed` + `screen_view(main_menu)`
  - `app.js`: `backToMode` → `screen_view(main_menu)`
  - `solo.js`: `startSoloMode` → `screen_view(solo_game)` + `solo_game_started`, `makeGuessSolo` → `guess_submitted` + `solo_game_won/lost`
  - `multiplayer.js`: `createRoom` → `game_mode_selected` + `room_created`, `joinRoom` → `room_joined(code)`, `showMultiplayerGame` → `screen_view(multiplayer_game)`, `makeGuessMulti` → `guess_submitted`, `showMultiResult` → `game_won/lost`, `leaveRoom` → `room_left`
  - `league.js`: `showLeagueHome` → `screen_view(league_home)`, `startLeagueMatch` → `screen_view(league_game)` + `room_joined("league_level_N")` (iOS ProgressionManager와 동일 패턴), `makeLeagueGuess` → `guess_submitted`, `endLeagueMatch` → `game_won/lost(mode=league)`
- `main.css` (이번 커밋에 동봉된 폴리시): 입력/`.last-guess` 모노스페이스 폰트 + letter-spacing 조정으로 자릿수 정렬, 리그 히스토리 행에 grid 레이아웃 적용

### 배포·검증
- `./web/deploy.sh --deploy` (Firebase CLI 토큰 만료로 `firebase login --reauth` 선행)
- 라이브 사이트 v4.4 + `firebase-analytics-compat.js` 로드 확인
- GA4 실시간 리포트에서 웹 사용자 잡힘 (사용자 직접 확인)

### 다음에 할 일 (변경 없음)
- Phase 3 (진행 관리 키 TTL + Firebase 익명 로그인)
- Phase 4 (리더보드 — 솔로 먼저, RTDB 데이터 그대로 활용)

---

## 2026-06-09 — Phase 2: 5단계 리그 CPU 대전 (이어서)

### 완료한 작업 — CPU 리그 컨버트
- iOS 앱의 `CPUStrategy.swift` 알고리즘 4종을 JS로 1:1 포팅
  - `web/src/js/league/strategy.js` (200줄): `randomStrategy`, `eliminationStrategy`, `entropyStrategy`, `minimaxStrategy` + `_withNoise` 래퍼
  - 720개 후보 풀 (`ALL_CANDIDATES`), `_consistentWith(history)` 헬퍼
  - `LEAGUE_LEVEL_CONFIGS`: 5단계 (Beginner/Intermediate/Advanced/Expert/Master) — iOS의 1~5와 동일하지만 웹 딜레이는 0.45~0.8초로 단축
- `web/src/js/league/league.js` (210줄): 게임 루프 + UI/상태
  - **Firebase RTDB 미사용** — 메모리 안에서만 처리, 네트워크 왕복 0
  - 사용자/CPU가 각자 비밀 숫자 보유. 사용자 추측 → CPU 차례 → setTimeout으로 자연스러운 딜레이 → CPU 추측 → 반복
  - 진행 관리: `localStorage["baseballLeagueUnlocked"]` 단순 카운터 (이긴 레벨+1까지 잠금 해제, 1~5)
  - Phase 3의 키 TTL 시스템은 의도적으로 미룸
- UI 통합: `index.html`의 모드 선택에 "🏆 리그 도전" 카드 추가, `leagueHome`(레벨 카드 5장) + `leagueGame`(턴제 화면) 섹션 추가
- `i18n.js` 확장: 한/영 모두에 리그 텍스트 ~25개 추가 (`league.level`, `league.levelName.N`, `league.cpuThinking` 등)
- `css/main.css` 확장: `.level-card`, `.level-card.locked`, `.history-actor`, `.history-item-cpu`, `#leagueTurnInfo` 등
- `solo.js`/`multiplayer.js`/`app.js`: 결과 모달 버튼 토글 + `hideAllSections` + `backToMode`에서 리그 잔여 상태 정리

### Phase 2 설계 결정 (기록)
- **백엔드 인프라 추가 0**. iOS와 동일하게 클라이언트 사이드 CPU.
- **RTDB 미사용**: iOS는 rooms 컬렉션 안에서 시뮬레이션했지만, 웹은 메모리 안에서 처리해 쿼터 절약 + 빠름.
- **알고리즘 호환성**: `BaseballLogic.strikeBall`을 JS의 `_strikeBall`/`calculateResult`로 동일 시그니처 유지. iOS와 결과 비트 단위 일치.
- 엔트로피/미니맥스 성능: 720×720 ≈ 50만 회 비교, V8에서 10~30ms — 사용자 체감 없음.

### 진행 상황 — iOS → 웹 컨버트 단계
- Phase 0: 인프라 진단 ✅
- Phase 1: 멀티 + 솔로 분리/배포 ✅
- Phase 2: 5단계 리그 CPU ✅
- Phase 3: 진행 관리(키 TTL) + Firebase 익명 로그인 ⬜
- Phase 4: 리더보드 (솔로 + 리그) ⬜
- Phase 5: 다국어 전면 확장 + 마무리 ⬜

### 다음에 할 일
- **Phase 4(솔로 리더보드 먼저)**: 익명 로그인 + 리더보드 읽기. RTDB 규칙(`leaderboards/solo`)이 이미 배포되어 있고 iOS 사용자가 쌓아둔 데이터가 그대로 보임. ~1시간 작업으로 가장 가성비 높음. (분석 메모: 리더보드 자체는 어렵지 않음 — 어려운 건 키 TTL 시스템이고 그건 Phase 3로 분리됨)
- **Phase 2 후속 확인**: Level 6 (Grandmaster, minimax)은 현재 의도적으로 빠짐. iOS와 일치시키려면 `LEAGUE_LEVEL_CONFIGS[6]` 추가 + UI에서 5→6으로 확장. 사용자 결정 사항.

---

## 2026-06-09 — Phase 1: 웹 버전 sinbiroum.com/baseball 배포

### 완료한 작업 — iOS 앱 → 웹 컨버트 1단계
- 기존 `number_baseball_multiplayer-v3.1.html`(1607줄 단일 파일)을 `web/src/` 모듈 구조로 분리
  - `web/src/index.html` (마크업), `css/main.css`, `manifest.json`, `assets/icon-192.png|512.png`
  - JS는 6개로 분리: `i18n.js`, `baseball-logic.js`(순수 로직), `firebase-config.js`, `solo.js`, `multiplayer.js`, `app.js`
  - 전역 함수 패턴 유지 → 기존 onclick 핸들러 무수정
- `web/deploy.sh` 작성 — rsync로 `sinbiroum-web/public/baseball/`에 복사 후 `--deploy` 옵션으로 `firebase deploy --only hosting:sinbiroum-v1`까지 일체 처리
- sinbiroum-web 레포의 `firebase.json`에 `/baseball/**` 전용 CSP 헤더 추가
  - Firebase RTDB (`*.firebaseio.com`, `wss://*.firebaseio.com`), Auth, Installations API 허용
  - 후행 매치 우선 규칙으로 다른 경로(`/`, `/privacy` 등)에는 영향 없음
- 라이브 검증: <https://sinbiroum.com/baseball/> 200, 모든 자산(JS 6 + CSS + manifest + 아이콘 2) 200, 기존 메인 페이지 영향 없음

### 진행 상황 — iOS → 웹 컨버트 단계
- **Phase 0**: sinbiroum.com 인프라 진단 ✅ (Firebase Hosting + Fastly CDN, sinbiroum-web 레포에서 관리)
- **Phase 1**: 기존 멀티플레이어 HTML 정리 + 배포 ✅
- **Phase 2**: 5단계 리그 CPU 대전 컨버트 (가장 무거운 단계) ⬜ 다음 세션
- **Phase 3**: 진행 관리(키/TTL) + Firebase 익명 로그인 ⬜
- **Phase 4**: 리더보드 ⬜
- **Phase 5**: 다국어 전면 확장 + 마무리 ⬜

### 다음에 할 일
- **Phase 2 (다음 세션 시작 시 우선)**: 5단계 리그 CPU 대전
  - 포팅 대상 Swift 파일: `CPUStrategy.swift`(elimination/entropy 전략, 202줄), `CPUPlayer.swift`(155줄), `LeagueHomeView.swift`(215줄), `ProgressionManager.swift`(키 TTL은 Phase 3로)
  - 권장 위치: `web/src/js/league/` 디렉토리에 `strategy.js`, `cpu-player.js`, 그리고 `league.js`(UI)
  - 솔로 모드 흐름 옆에 "리그 도전" 진입점 추가 (5단계 카드 그리드)
- sinbiroum.com 메인 페이지에서 Number Baseball 진입 동선 추가 (이번 세션 직후 진행)

---

## 2026-03-26

### 완료한 작업
- GitHub 레포 로컬 데이터로 재세팅
  - .gitignore 생성 (service-account.json, GoogleService-Info.plist 등 민감 파일 제외)
  - Git 초기화 및 로컬 전체 파일 커밋
  - CLAUDE.md 작성
  - 기존 GitHub Public 레포에 force push

### 기술 스택 요약
- iOS: Swift, SwiftUI, Firebase SDK
- Cloud Functions: Node.js 20, Firebase Functions
- Worker/Bot: Python, firebase-admin, PyYAML
- 인프라: Firebase (Realtime DB, Hosting, Analytics)
