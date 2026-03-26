# Number Baseball

## 세션 시작 시 할 일
1. `git pull origin main` — 원격 변경사항 동기화
2. `DEV_NOTES.md` 확인 — 이전 세션의 진행 상황 및 다음 할 일 파악

## 세션 종료 시 할 일
1. 변경사항 커밋 및 `git push origin main`
2. `DEV_NOTES.md` 업데이트 — 오늘 한 작업, 다음에 할 일 기록

## 프로젝트 개요
iOS 숫자야구 게임. 3자리 숫자를 추리하는 두뇌 게임으로, 온라인 멀티플레이어 대전과 CPU 대전(5단계 리그)을 지원. 서버사이드 봇 엔진과 외부 개발자용 Bot SDK를 포함.

## 기술 스택
- **iOS 앱**: Swift, SwiftUI, SwiftPM, Firebase SDK
- **Cloud Functions**: Node.js 20, Firebase Functions (DB 정리용)
- **Worker (봇 엔진)**: Python, firebase-admin, PyYAML
- **Bot SDK**: Python, firebase-admin, PyYAML (외부 개발자용)
- **인프라**: Firebase Realtime Database, Firebase Hosting, Firebase Analytics

## 디렉토리 구조
```
number-baseball/
├── number-baseball/              # iOS Xcode 프로젝트
│   ├── number-baseball.xcodeproj
│   └── number-baseball/          # Swift 소스 (Views, Models, Logic)
├── functions/                    # Firebase Cloud Functions (Node.js)
│   └── index.js
├── worker/                       # 서버사이드 봇 엔진 (Python)
│   ├── strategy/                 # 봇 전략 모듈 (elimination, entropy 등)
│   ├── config-level*.yaml        # 리그 레벨별 봇 설정
│   └── config-*.yaml             # 개별 봇 설정
├── bot-sdk/                      # 외부 개발자용 Bot SDK (Python)
│   ├── sdk/                      # SDK 코어
│   └── examples/                 # 전략 예제
├── *.html                        # 멀티플레이어 웹 테스트 페이지
├── *.sh                          # 봇 실행 스크립트
├── firebase.json                 # Firebase 설정
├── database.rules.json           # Realtime DB 보안 규칙
├── CLAUDE.md
└── DEV_NOTES.md
```

## 주요 실행 명령어
- **iOS 앱 빌드**: Xcode에서 `number-baseball.xcodeproj` 열기
- **Worker 실행**: `cd worker && python -m worker --config config.yaml`
- **Bot SDK 실행**: `cd bot-sdk && python run.py`
- **Cloud Functions 배포**: `cd functions && firebase deploy --only functions`
- **DB 규칙 배포**: `firebase deploy --only database`
- **로컬 테스트**: `firebase emulators:start`

## 주의사항
- `service-account.json` — Firebase Private Key 포함, 절대 git에 포함 금지
- `GoogleService-Info.plist` — Firebase API Key 포함, git에서 제외됨
- `.firebaserc` — 로컬 Firebase 프로젝트 매핑, git에서 제외됨
- `bot-sdk/game_records/` — 런타임 게임 로그, git에서 제외됨
- 이 레포는 **Public**이므로 민감 정보 커밋에 각별히 주의
