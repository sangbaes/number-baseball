# 🎮 숫자야구 게임 - 최종 버전

## 📦 다운로드

**최신 버전: v2.5 (Opponent Info)**

파일: `number_baseball_multiplayer.html`

---

## 🎯 버전 히스토리

### v2.5 (2024-01-08) - Opponent Last Guess Display
**새로운 기능:**
- ✅ 상대방 최근 시도 결과 실시간 표시
- ✅ 턴제 모드에서 상대방이 추측한 숫자와 결과를 볼 수 있음
- ✅ "123 → 1S 1B" 형식으로 표시
- ✅ 더욱 전략적이고 긴장감 있는 게임플레이

**화면 예시:**
```
🔵 나              🔴 상대방
5회                3회
플레이 중...       플레이 중...
456 → 2S          789 → 1S 1B
```

---

### v2.4 (2024-01-08) - Turn-based Mode
**새로운 기능:**
- ✅ 턴제 대결 모드 추가
- ✅ 게임 종료 후 "새 게임" / "나가기" 선택
- ✅ 턴 표시 UI (당신 차례 / 상대방 차례)
- ✅ 자동 턴 교체 시스템
- ✅ 턴에 따른 입력 제어

**게임 방식:**
- ⚡ 동시 대결: 누가 먼저 맞추나 경쟁
- 🔄 턴제 대결: 번갈아가며 전략적으로 추측

---

### v2.3 (2024-01-08) - Multi+Solo
**새로운 기능:**
- ✅ 언어 선택 (🇰🇷 한국어 / 🇺🇸 English)
- ✅ 혼자하기 모드 추가
- ✅ 3가지 게임 모드 (방 만들기 / 방 입장 / 혼자하기)
- ✅ 완전한 다국어 지원

---

### v2.2 (2024-01-06) - Analytics
**새로운 기능:**
- ✅ Google Analytics 추적
- ✅ GitHub Traffic 통계
- ✅ 사용자 추적 시스템

---

### v2.1 (2024-01-06) - Firebase Multiplayer
**새로운 기능:**
- ✅ Firebase 실시간 멀티플레이어
- ✅ 방 만들기 / 입장 시스템
- ✅ 6자리 방 코드
- ✅ 메시지로 친구 초대
- ✅ 실시간 상대방 진행 상황 표시

---

### v2.0 (2024-01-05) - Difficulty Levels
**새로운 기능:**
- ✅ 3가지 난이도 (3자리 / 4자리 / 5자리)
- ✅ 난이도 선택 UI
- ✅ 동적 입력 검증

---

### v1.0 (2024-01-05) - Initial Release
**기본 기능:**
- ✅ 3자리 숫자야구 게임
- ✅ PWA 지원
- ✅ 오프라인 작동
- ✅ 30회 시도 제한

---

## 🎮 현재 버전 (v2.5) 주요 기능

### 게임 모드
1. **혼자하기** 🎯
   - 연습용 싱글플레이
   - 30회 시도 제한
   - 점수 기록

2. **동시 대결** ⚡
   - 실시간 멀티플레이어
   - 누가 먼저 맞추나 경쟁
   - 상대방 진행 상황 실시간 표시
   - 상대방 최근 시도 결과 표시 (NEW!)

3. **턴제 대결** 🔄
   - 번갈아가며 추측
   - 전략적인 플레이
   - 턴 표시 및 입력 제어
   - 상대방 시도 결과 보고 전략 수립 (NEW!)

### 다국어
- 🇰🇷 한국어
- 🇺🇸 English

### 멀티플레이어
- 6자리 방 코드
- 메시지로 친구 초대
- 같은 친구와 연속 대결 (새 게임)
- Firebase 실시간 동기화

### PWA
- 홈 화면 추가
- 오프라인 작동
- 앱처럼 실행

---

## 📥 설치 방법

### 1. 파일 다운로드
- `number_baseball_multiplayer.html` - 메인 게임 파일
- `manifest_multiplayer.json` - PWA 설정
- `icon-192.png` - 앱 아이콘 (192x192)
- `icon-512.png` - 앱 아이콘 (512x512)

### 2. GitHub Pages 배포
```bash
1. GitHub repository 생성
2. 파일들 업로드
3. Settings → Pages → main branch 선택
4. 완료! URL 생성됨
```

### 3. Firebase 설정
```javascript
// HTML 파일 내부에서 수정:
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  databaseURL: "https://YOUR_PROJECT.firebaseio.com",
  ...
};
```

---

## 🎯 게임 플레이

### 혼자하기
1. 언어 선택
2. "🎯 혼자하기" 클릭
3. 3자리 숫자 맞추기
4. 30회 시도 제한

### 동시 대결
1. "🏠 방 만들기" → "⚡ 동시 대결"
2. 코드 공유
3. 친구 입장
4. 동시에 추측 시작!

### 턴제 대결
1. "🏠 방 만들기" → "🔄 턴제 대결"
2. 코드 공유
3. 친구 입장
4. 번갈아가며 추측!

---

## 🔧 기술 스택

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Firebase Realtime Database
- **PWA**: Service Worker, Web App Manifest
- **Analytics**: Google Analytics
- **Hosting**: GitHub Pages / Netlify / Vercel

---

## 📊 통계

### Firebase 사용량 (무료 플랜)
- 동시 접속: 100명
- 저장 공간: 1GB
- 다운로드: 10GB/월

### Google Analytics
- 실시간 사용자 추적
- 새 게임 시작 횟수
- 난이도별 선호도
- 지역별 통계

---

## 🎉 특별 감사

- Firebase: 실시간 데이터베이스
- Google Analytics: 사용자 추적
- GitHub Pages: 무료 호스팅

---

## 📞 지원

문제가 있거나 제안 사항이 있으면:
1. GitHub Issues 등록
2. 또는 개발자에게 문의

---

## 🚀 향후 계획

### 계획 중인 기능:
- [ ] 3명 이상 멀티플레이어
- [ ] 리더보드 / 순위표
- [ ] 채팅 기능
- [ ] 난이도 추가 (4자리, 5자리)
- [ ] 게임 모드 추가 (제한 시간)
- [ ] 업적 시스템
- [ ] 프로필 시스템

---

## 📝 라이선스

MIT License - 자유롭게 사용, 수정, 배포 가능

---

**최종 업데이트:** 2024-01-08  
**버전:** v2.5 (Opponent Info)  
**개발자:** Claude AI Assistant

즐거운 게임 되세요! 🎮✨
