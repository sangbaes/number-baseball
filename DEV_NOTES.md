# DEV_NOTES

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
