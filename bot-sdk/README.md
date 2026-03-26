# Number Baseball Bot SDK

숫자야구 게임의 봇을 만들 수 있는 SDK입니다.
전략 로직 하나만 구현하면 나만의 봇이 완성됩니다.

## Game Rules

3자리 숫자(각 자리 중복 없음, 0-9)를 맞추는 게임입니다.

| 결과 | 의미 |
|------|------|
| Strike | 숫자와 위치 모두 맞음 |
| Ball | 숫자는 맞지만 위치가 다름 |
| 3 Strike | 정답! |

예시: 정답이 `152`일 때 `125`를 추측하면 → 1S 2B

## Quick Start

### 1. Clone & Install

```bash
git clone <this-repo>
cd bot-sdk
pip install -r requirements.txt
```

### 2. Firebase Setup

Firebase 서비스 계정 키가 필요합니다:

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택 → 설정(톱니바퀴) → 서비스 계정
3. "새 비공개 키 생성" 클릭
4. 다운로드된 JSON 파일을 `service-account.json`으로 이름 변경하여 `bot-sdk/` 디렉토리에 배치

### 3. Config

`config.yaml`을 수정하세요:

```yaml
firebase:
  service_account: "./service-account.json"
  database_url: "https://your-project.firebaseio.com"

bot:
  name: "나의봇"              # 앱에 표시되는 이름
  group_code: "BOT"           # 공개방 그룹코드
  strategy: "my_strategy"     # 전략 파일명 (.py 제외)
  guess_delay_seconds: 2.0    # 추측 간격 (초)
  level: 1                    # 난이도 표시 (1~3)
```

### 4. Run

```bash
python run.py
```

봇이 자동으로 공개방을 만들고 상대를 기다립니다.
게임이 끝나면 한판더 요청을 기다린 후 새 방을 만듭니다.

## Making Your Strategy

`my_strategy.py`를 수정하세요. 구현할 것은 딱 하나:

```python
from sdk import Strategy, GuessResult, ALL_CANDIDATES, filter_candidates

class MyStrategy(Strategy):

    @property
    def name(self) -> str:
        return "My Strategy"

    def reset(self) -> None:
        """새 게임 시작 시 호출됩니다."""
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        """다음 추측을 반환합니다.

        history: 이전 추측과 결과의 리스트
            history[i].guess  -> "123"  (추측한 숫자)
            history[i].strike -> 1      (스트라이크 수)
            history[i].ball   -> 1      (볼 수)

        Returns: 3자리 서로 다른 숫자 문자열 (예: "407")
        """
        # 여기에 당신의 전략을 구현하세요!
        return "123"
```

### SDK Helper Functions

전략 구현 시 활용할 수 있는 유틸리티:

```python
from sdk import strike_ball, filter_candidates, ALL_CANDIDATES

# ALL_CANDIDATES: 가능한 모든 3자리 숫자 (720개)
# ["012", "013", ..., "987"]

# strike_ball("123", "132") -> (1, 2)
# 1 Strike (1이 맞음), 2 Ball (3과 2가 자리만 다름)

# filter_candidates(candidates, "123", 1, 2)
# -> "123"을 추측해서 1S 2B가 나올 수 있는 후보만 필터링
```

## Examples

`examples/` 폴더에 참고할 수 있는 전략들이 있습니다:

| 파일 | 난이도 | 설명 |
|------|--------|------|
| `random_strategy.py` | Easy | 매번 랜덤 추측 |
| `elimination_strategy.py` | Medium | 불가능한 후보를 제거하고 랜덤 선택 |
| `entropy_strategy.py` | Hard | 정보 이론 기반 최적 추측 |

사용법: 파일을 `bot-sdk/` 루트에 복사하고 config.yaml에서 strategy 변경:

```bash
cp examples/entropy_strategy.py .
```

```yaml
bot:
  strategy: "entropy_strategy"
```

## Architecture

```
bot-sdk/
├── run.py              # 실행 진입점
├── my_strategy.py      # ← 이것만 수정!
├── config.yaml         # ← 이것만 설정!
├── sdk/                # SDK 코어 (수정 불필요)
│   ├── engine.py       # 게임 엔진 (방 생성, 게임 진행, 리매치)
│   ├── baseball.py     # 게임 로직 (S/B 계산, 후보 필터링)
│   ├── strategy.py     # Strategy 인터페이스
│   ├── firebase_client.py
│   ├── presence.py
│   ├── config.py
│   └── cleanup.py
└── examples/           # 전략 예제들
```

**분리 원칙:**
- `sdk/` 폴더는 건드리지 않습니다
- 사용자는 전략 파일과 config만 수정합니다
- 전략은 `next_guess(history)` 하나만 구현하면 됩니다

## Fair Play

봇은 정답을 알 수 없습니다.
`next_guess(history)`는 이전 추측의 Strike/Ball 결과만 받으며,
이는 사람 플레이어와 동일한 조건입니다.

## License

MIT
