# 리그 모드 리팩토링: 워커를 "추론 전용"으로 전환

## 현재 문제 (왜 리팩토링이 필요한가)

현재 구조는 **워커가 방을 만들고 iOS가 들어오는** 방식이다.
이로 인해 다음 문제들이 끊임없이 발생한다:

1. **좀비 방**: iOS가 leaveRoom()으로 나가면, 워커가 상대 이탈을 감지 못해 방이 playing 상태로 남는다. publicRooms에서도 이미 제거되어 새 사용자가 찾을 수 없다.
2. **Stale 콜백**: iOS의 listenRoom()이 Task{@MainActor}로 비동기 dispatch하기 때문에, leaveRoom() 후에도 이전 방의 콜백이 실행되어 새 방의 outcome을 오염시킨다.
3. **책임 충돌**: 워커가 방 생성/정리를, iOS가 게임 진행(maybeStartGameIfReady, maybeDecideOutcome)을 담당하여, 두 시스템 사이 타이밍 오류가 끊임없이 발생한다.

## 새 아키텍처: "iOS가 모든 방 lifecycle 소유, 워커는 추론만"

### 핵심 원칙
- **iOS가 방을 만든다** (createRoom이 아닌 새로운 createBotRoom)
- **iOS가 워커를 배정한다** (workerPool에서 idle 워커를 찾아 배정)
- **워커는 rooms/ 경로를 직접 건드리지 않는다**
- **워커는 전용 경로(botWorkers/{workerId})만 listen한다**
- **iOS가 방 정리를 한다** (leaveRoom에서 모든 것을 정리)

### RTDB 데이터 구조

```
botWorkers/
  L01-Main-Frame-1/
    status: "idle"              ← 워커가 관리 (idle | playing)
    config:
      name: "Bot-Beginner"
      level: 1
      groupCode: "L01"
    assignment:                  ← iOS가 쓰고, 워커가 읽는다
      roomCode: "ABC12"
      turnSecret: "385"
      opponentName: "Kim"
      assignedAt: {.sv: timestamp}
    guess:                       ← 워커가 쓰고, iOS가 읽는다
      value: "482"
      strike: 1
      ball: 1
      round: 3
      ts: {.sv: timestamp}
    chat:                        ← 워커가 쓴다
      text: "Nice try! 🎉"
      ts: {.sv: timestamp}

rooms/{code}/                    ← iOS만 관리 (기존 구조 유지)
  status, players, rounds, turnSecret, outcome, ...
  assignedWorker: "L01-Main-Frame-1"   ← 어떤 워커가 배정됐는지

publicRooms/{groupCode}/{code}/  ← iOS만 관리
```

### 데이터 흐름 (한 게임의 전체 흐름)

```
[iOS - 리그 시작]
1. iOS: publicRooms 조회 대신 → botWorkers/ 에서 status="idle"인 워커를 찾는다
2. iOS: 방 생성 (rooms/{code}, publicRooms 불필요 - 리그에선 매칭이 자동)
3. iOS: 워커에게 배정 (botWorkers/{workerId}/assignment에 roomCode, turnSecret 기록)
4. iOS: rooms/{code}/assignedWorker = workerId 기록
5. iOS: rooms/{code}/players/p1 = 워커 이름 기록 (iOS가 대신 등록)
6. iOS: rooms/{code}/players/p2 = 사용자 이름 기록
7. iOS: maybeStartGameIfReady → status=playing, turnSecret, currentTurn=p1

[게임 진행 - 워커 턴]
8. 워커: assignment 감지 → status를 "playing"으로 변경
9. 워커: assignment.turnSecret으로 guess 계산
10. 워커: botWorkers/{workerId}/guess에 결과 기록 (value, strike, ball, round)
11. iOS: guess 변경 감지 (listenWorker) → rooms/{code}/rounds에 반영 + currentTurn=p2

[게임 진행 - 사용자 턴]
12. iOS: 사용자 입력 → rooms/{code}/rounds에 기록 + currentTurn=p1
13. iOS: currentTurn=p1 감지 → (워커는 자동으로 다음 guess 계산)
    ※ 워커가 rooms를 listen하지 않으므로, iOS가 "다음 턴 시그널"을 보내야 함
    → botWorkers/{workerId}/assignment/currentRound를 업데이트하거나
    → 워커가 rooms/{code}/currentTurn만 listen하는 방식

[게임 종료]
14. 3S 발생 → iOS: maybeDecideOutcome → outcome 설정
15. 워커: outcome 감지 또는 iOS가 assignment을 삭제 → status="idle"로 복귀
16. iOS: 방 정리 (leaveRoom)

[Next Level]
17. iOS: 새 방 생성 → 새 워커 배정 → 3부터 반복
```

### 단순화 방안 (방식 A - 권장)

위의 방식이 너무 복잡하면, **더 단순한 방식**:

```
워커는 rooms/{code}를 여전히 listen하지만:
- 방 생성을 하지 않는다
- 방 정리를 하지 않는다
- publicRooms를 건드리지 않는다
- 워커 풀은 botWorkers/{workerId}/status로 관리

흐름:
1. 워커 시작 → botWorkers/{workerId}/status = "idle" 등록
2. iOS: idle 워커 찾기 → 방 생성 → rooms/{code}에 워커를 p1로 등록
3. iOS: botWorkers/{workerId}/assignment = {roomCode: "ABC"} 기록
4. 워커: assignment 감지 → rooms/ABC를 listen 시작
5. 게임 진행 (현재와 동일 - 워커가 guess 제출, iOS가 outcome 결정)
6. 게임 종료 → 워커: rooms listen 해제, status = "idle"
7. iOS: 방 정리
8. Next Level → iOS가 새 워커 찾아서 배정
```

## 수정 대상 파일

### Python (워커)

#### 1. `worker/game_engine.py` - 대폭 수정
- `_do_idle()`: 방 생성 제거 → `botWorkers/{workerId}/status = "idle"` 등록 + assignment listen 시작
- `_do_lobby()`: 제거 또는 → assignment에 roomCode가 올 때까지 대기
- `_do_playing()`: 유지 (rooms/{code} listen, guess 제출)
- `_do_finished()`: 방 정리 제거 → rooms listen 해제, status = "idle"로 복귀
- `_safe_cleanup()`: room_manager.cleanup_room() 제거

#### 2. `worker/room_manager.py` - 삭제 또는 대폭 축소
- create_room() 삭제
- cleanup_room() 삭제
- cleanup_stale_rooms() → botWorkers/{workerId} 정리로 변경

#### 3. `worker/__main__.py` 또는 `worker/__init__.py` - RoomManager 의존성 제거

### Swift (iOS)

#### 4. `ProgressionManager.swift` - `findAndJoinBotRoom()` 대폭 수정
현재: publicRooms에서 방을 찾아서 joinRoom()
변경:
- botWorkers/에서 idle 워커 찾기
- 방을 직접 생성 (svc.createBotRoom)
- 워커에게 assignment 기록
- listenRoom() 시작

#### 5. `RoomService.swift` - 새 함수 추가
- `createBotRoom(workerName:, workerConfig:)` - 리그용 방 생성 (p1=워커, p2=사용자로 동시 등록)
- `leaveRoom()` 수정 - 워커 assignment 정리 추가
- `listenRoom()` 수정 - stale callback 가드 유지
- `maybeStartGameIfReady()` - 변경 없음

#### 6. `RoomFlowView.swift`
- handleNextLevel/handleRetry - 워커 assignment 정리 로직 추가
- 기존 asyncAfter → Task 수정 유지

#### 7. `LeagueHomeView.swift`
- refreshBotCounts() 수정 - publicRooms 대신 botWorkers에서 idle 워커 수 조회

## 마이그레이션 주의사항

1. **botWorkers 경로 초기화**: 워커 시작 시 자신의 botWorkers/{workerId} 노드를 생성해야 함
2. **Firebase Rules**: botWorkers/ 경로에 대한 읽기/쓰기 권한 설정 필요
3. **워커 재시작 처리**: 워커가 비정상 종료 후 재시작하면, 이전 assignment가 남아있을 수 있음 → 시작 시 stale assignment 정리
4. **publicRooms는 일반 멀티플레이어에서 계속 사용**: 리그 모드에서만 botWorkers 방식 사용
5. **워커 프로세스 관리**: run-league-bots.sh는 변경 없음 (워커 시작/중단만 담당)

## 테스트 체크리스트

- [ ] 워커 시작 → botWorkers에 idle로 등록되는지
- [ ] iOS 리그 입장 → idle 워커 찾아서 방 생성 + 배정
- [ ] 게임 정상 진행 (턴 교대, guess, outcome)
- [ ] iOS 승리 → Next Level → 새 워커 배정 → L2 정상 진행
- [ ] iOS 패배 → Retry → 같은 레벨 워커 재배정
- [ ] iOS가 중간에 나가기 → 워커가 idle로 복귀
- [ ] 워커 비정상 종료 → iOS가 감지하고 에러 표시
- [ ] 여러 사용자 동시 접속 → 각각 다른 워커에 배정
