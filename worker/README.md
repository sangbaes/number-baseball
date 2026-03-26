# Number Baseball Bot Worker

Firebase Realtime DB를 통해 숫자야구 게임에 AI 대전 상대로 참여하는 Python 봇.

## 설치

```bash
cd worker
pip install -r requirements.txt
```

## Firebase 서비스 계정 설정

1. [Firebase Console](https://console.firebase.google.com/project/number-baseball-28392/settings/serviceaccounts/adminsdk) 접속
2. **Generate New Private Key** 클릭
3. 다운로드한 JSON 파일을 `worker/service-account.json`으로 저장

## 실행

```bash
# 프로젝트 루트에서
cd /Users/sangbaekim/Project/Lab1/number-baseball
python -m worker
```

## 설정 (config.yaml)

```yaml
firebase:
  service_account: "./service-account.json"
  database_url: "https://number-baseball-28392-default-rtdb.firebaseio.com"

bot:
  name: "Bot-Medium"        # 게임에서 표시되는 이름
  group_code: "B07"          # 공개 방 그룹 코드 (3자리 hex)
  strategy: "elimination"    # random | elimination | entropy
  restart_delay_seconds: 3   # 게임 종료 후 새 방 생성까지 대기
  guess_delay_seconds: 2.0   # 추측 사이 인위적 딜레이 (자연스러움)
  heartbeat_interval: 15     # presence 하트비트 간격 (초)
```

## 전략

| 이름 | 난이도 | 설명 |
|------|--------|------|
| `random` | Easy | 매번 랜덤 추측 (필터링 없음) |
| `elimination` | Medium | 이전 결과로 후보 소거, 남은 중 랜덤 선택 |
| `entropy` | Hard | 정보 엔트로피 최대화 — 평균 ~5-6회 정답 |

## 동작 방식

1. 봇이 공개 턴제 방을 생성하고 대기
2. iOS 앱 유저가 공개 방 목록에서 봇 방 발견 → 입장
3. 턴제 대전 진행 (봇 ↔ 유저 교대 추측)
4. 게임 종료 후 자동으로 새 방 생성 (반복)

## LLM 플러그인 (향후)

`strategy/llm_plugin.py`에 Strategy 인터페이스를 구현하여 LLM API 기반 추론 전략으로 교체 가능.
