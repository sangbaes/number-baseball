# DEV_NOTES

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
