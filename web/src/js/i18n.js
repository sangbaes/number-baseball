// Translations and language switching.
// Exposes globals: translations, currentLang, setLanguage(), updateTexts(), getText().

const translations = {
    ko: {
        mainTitle: "🎮 숫자야구",
        mainSubtitle: "게임 모드를 선택하세요",
        createRoomTitle: "방 만들기",
        createRoomDesc: "친구를 초대하세요",
        joinRoomTitle: "방 입장",
        joinRoomDesc: "코드로 입장하기",
        soloModeTitle: "혼자하기",
        soloModeDesc: "혼자서 연습하기",
        gameModeTitle: "게임 방식 선택",
        simultaneousTitle: "동시 대결",
        simultaneousDesc: "누가 먼저 맞추나!",
        turnBasedTitle: "턴제 대결",
        turnBasedDesc: "번갈아가며 추측",
        joinTitle: "방 코드 입력",
        joinBtn: "입장하기",
        backBtn: "돌아가기",
        roomCodeLabel: "방 코드",
        shareText: "이 코드를 친구에게 공유하세요!",
        copyBtn: "📋 코드 복사",
        shareBtn: "📤 메시지로 공유",
        waitingText: "친구를 기다리는 중...",
        leaveBtn: "나가기",
        meLabel: "🔵 나",
        opponentLabel: "🔴 상대방",
        attemptsUnit: "회",
        myStatusPlaying: "플레이 중...",
        opponentStatusPlaying: "플레이 중...",
        myStatusWin: "🏆 승리!",
        opponentStatusWin: "🏆 승리!",
        guessBtn: "추측하기",
        soloAttemptsLabel: "시도: ",
        newGameBtn: "새 게임",
        playAgainBtn: "새 게임",
        yourTurn: "당신 차례입니다!",
        opponentTurn: "상대방 차례입니다...",
        waitingForOpponent: "상대방을 기다리는 중...",
        winTitle: "승리!",
        winDetail: "{attempts}번 만에 맞추셨습니다!",
        loseTitle: "패배...",
        loseDetail: "상대방이 {attempts}번 만에 맞췄습니다.",
        soloWinTitle: "축하합니다!",
        soloWinDetail: "{attempts}번 만에 맞추셨습니다!\n정답: {answer}",
        soloLoseTitle: "아쉽네요!",
        soloLoseDetail: "30번 시도했지만 맞추지 못했습니다.\n정답: {answer}",
        closeModalBtn: "확인",
        closeModalBtn2: "나가기",
        errorDigits: "⚠️ 3자리 숫자를 입력하세요",
        errorRepeating: "⚠️ 중복되지 않는 숫자를 입력하세요",
        errorNotYourTurn: "⚠️ 상대방 차례입니다!",
        errorRoomCode: "6자리 방 코드를 입력하세요",
        errorNoRoom: "존재하지 않는 방입니다",
        errorStarted: "이미 시작된 게임입니다",
        errorAuth: "⚠️ 접속에 실패했습니다. 다시 시도해주세요.",
        codeCopied: "코드가 복사되었습니다: ",
        shareMessage: "숫자야구 게임에 초대합니다!\n방 코드: {code}\n\n링크로 바로 입장하기:\n{url}?room={code}",

        // League mode
        leagueModeTitle: "리그 도전",
        leagueModeDesc: "CPU와 5단계 대결",
        leagueTitle: "🏆 리그 도전",
        leagueDesc: "CPU와 5단계 리그에 도전하세요",
        leagueBackBtn: "돌아가기",
        leagueLeaveBtn: "게임 나가기",
        leagueGuessBtn: "추측하기",
        leagueMeLabel: "🔵 나",
        leagueTryAgainBtn: "다시 도전",
        leagueNextChallengeBtn: "다음 도전 →",
        leagueBackToLevelsBtn: "레벨 선택으로",
        "league.level": "레벨 {n}",
        "league.levelName.1": "초급",
        "league.levelName.2": "중급",
        "league.levelName.3": "고급",
        "league.levelName.4": "전문가",
        "league.levelName.5": "마스터",
        "league.readyToPlay": "도전 가능",
        "league.needWin": "레벨 {n} 승리 시 잠금 해제",
        "league.cpuThinking": "{cpu} 추리 중...",
        "league.youLabel": "나",
        "league.winTitle": "🏆 승리!",
        "league.winDetail": "{cpu} 격파! 레벨 {level} ({attempts}회)",
        "league.unlockedNext": "다음 레벨 {n} 잠금 해제!",
        "league.allCleared": "모든 레벨을 클리어했습니다!",
        "league.loseTitle": "패배...",
        "league.loseDetail": "{cpu}가 {attempts}번 만에 맞혔습니다.\n정답: {answer}\n(레벨 {level})",

        // How to Play — mirrors LocalizationManager.swift help.* keys
        helpLinkBtn: "ℹ️ 게임 방법",
        "help.title": "게임 방법",
        "help.goal": "목표",
        "help.goalDesc": "숫자가 겹치지 않는 비밀 3자리 숫자를 맞추세요.",
        "help.feedback": "피드백",
        "help.strikeDesc": "S (스트라이크) — 숫자와 위치 모두 맞음",
        "help.ballDesc": "B (볼) — 숫자는 맞지만 위치가 다름",
        "help.outDesc": "OUT — 맞는 숫자가 없음",
        "help.rules": "규칙",
        "help.rule1": "비밀 번호는 3자리 (0~9)이며 각 숫자는 한 번만 사용됩니다.",
        "help.rule2": "추측도 중복 없는 3자리 숫자여야 합니다.",
        "help.rule3": "불가: 112, 555, 000 (숫자 중복)",
        "help.example": "예시",
        "help.exampleTitle": "정답: 8 9 4",
        "help.ex1": "추측 123 → OUT (1,2,3 제거)",
        "help.ex2": "추측 456 → 1B (4,5,6 중 하나 맞음)",
        "help.ex3": "추측 789 → 2B (7,8,9 중 둘 맞음)",
        "help.ex4": "추측 489 → 3B (모두 맞지만 위치 다름)",
        "help.ex5": "추측 849 → 1S 2B (거의 다 왔다!)",
        "help.ex6": "추측 894 → 3S — 정답!",
        helpCloseBtn: "닫기"
    },
    en: {
        mainTitle: "🎮 Number Baseball",
        mainSubtitle: "Choose game mode",
        createRoomTitle: "Create Room",
        createRoomDesc: "Invite friends",
        joinRoomTitle: "Join Room",
        joinRoomDesc: "Enter room code",
        soloModeTitle: "Solo Play",
        soloModeDesc: "Practice alone",
        gameModeTitle: "Choose Game Mode",
        simultaneousTitle: "Simultaneous",
        simultaneousDesc: "Race to finish!",
        turnBasedTitle: "Turn-based",
        turnBasedDesc: "Take turns guessing",
        joinTitle: "Enter Room Code",
        joinBtn: "Join",
        backBtn: "Back",
        roomCodeLabel: "Room Code",
        shareText: "Share this code with friends!",
        copyBtn: "📋 Copy Code",
        shareBtn: "📤 Share via Message",
        waitingText: "Waiting for friend...",
        leaveBtn: "Leave",
        meLabel: "🔵 Me",
        opponentLabel: "🔴 Opponent",
        attemptsUnit: " attempts",
        myStatusPlaying: "Playing...",
        opponentStatusPlaying: "Playing...",
        myStatusWin: "🏆 Win!",
        opponentStatusWin: "🏆 Win!",
        guessBtn: "Submit",
        soloAttemptsLabel: "Attempts: ",
        newGameBtn: "New Game",
        playAgainBtn: "Play Again",
        yourTurn: "Your turn!",
        opponentTurn: "Opponent's turn...",
        waitingForOpponent: "Waiting for opponent...",
        winTitle: "Victory!",
        winDetail: "You got it in {attempts} attempts!",
        loseTitle: "Defeat...",
        loseDetail: "Opponent got it in {attempts} attempts.",
        soloWinTitle: "Congratulations!",
        soloWinDetail: "You got it in {attempts} attempts!\nAnswer: {answer}",
        soloLoseTitle: "Game Over!",
        soloLoseDetail: "You've used all 30 attempts.\nAnswer: {answer}",
        closeModalBtn: "OK",
        closeModalBtn2: "Leave",
        errorDigits: "⚠️ Please enter a 3-digit number",
        errorRepeating: "⚠️ Please enter non-repeating digits",
        errorNotYourTurn: "⚠️ Wait for your turn!",
        errorRoomCode: "Please enter a 6-digit room code",
        errorNoRoom: "Room does not exist",
        errorStarted: "Game already started",
        errorAuth: "⚠️ Connection failed. Please try again.",
        codeCopied: "Code copied: ",
        shareMessage: "Join my Number Baseball game!\nRoom Code: {code}\n\nDirect link:\n{url}?room={code}",

        // League mode
        leagueModeTitle: "League Challenge",
        leagueModeDesc: "5 tiers vs CPU",
        leagueTitle: "🏆 League Challenge",
        leagueDesc: "Take on the CPU across 5 tiers",
        leagueBackBtn: "Back",
        leagueLeaveBtn: "Leave Match",
        leagueGuessBtn: "Submit",
        leagueMeLabel: "🔵 Me",
        leagueTryAgainBtn: "Try Again",
        leagueNextChallengeBtn: "Next Challenge →",
        leagueBackToLevelsBtn: "Back to Levels",
        "league.level": "Level {n}",
        "league.levelName.1": "Beginner",
        "league.levelName.2": "Intermediate",
        "league.levelName.3": "Advanced",
        "league.levelName.4": "Expert",
        "league.levelName.5": "Master",
        "league.readyToPlay": "Ready to play",
        "league.needWin": "Beat Level {n} to unlock",
        "league.cpuThinking": "{cpu} thinking...",
        "league.youLabel": "Me",
        "league.winTitle": "🏆 Victory!",
        "league.winDetail": "Beat {cpu}! Level {level} ({attempts} attempts)",
        "league.unlockedNext": "Level {n} unlocked!",
        "league.allCleared": "All levels cleared!",
        "league.loseTitle": "Defeat...",
        "league.loseDetail": "{cpu} got it in {attempts} attempts.\nAnswer: {answer}\n(Level {level})",

        // How to Play
        helpLinkBtn: "ℹ️ How to Play",
        "help.title": "How to Play",
        "help.goal": "Goal",
        "help.goalDesc": "Guess the secret 3-digit number with no repeating digits.",
        "help.feedback": "Feedback",
        "help.strikeDesc": "S (Strike) — Correct digit in the correct position",
        "help.ballDesc": "B (Ball) — Correct digit in the wrong position",
        "help.outDesc": "OUT — No correct digits at all",
        "help.rules": "Rules",
        "help.rule1": "The secret number has 3 digits (0–9), each used only once.",
        "help.rule2": "Your guess must also have 3 unique digits.",
        "help.rule3": "Invalid: 112, 555, 000 (repeating digits)",
        "help.example": "Example",
        "help.exampleTitle": "Secret: 8 9 4",
        "help.ex1": "Guess 123 → OUT (eliminate 1,2,3)",
        "help.ex2": "Guess 456 → 1B (one of 4,5,6 correct)",
        "help.ex3": "Guess 789 → 2B (two of 7,8,9 correct)",
        "help.ex4": "Guess 489 → 3B (all correct, wrong positions)",
        "help.ex5": "Guess 849 → 1S 2B (getting closer)",
        "help.ex6": "Guess 894 → 3S — You win!",
        helpCloseBtn: "Close"
    }
};

let currentLang = 'ko';

function setLanguage(lang) {
    currentLang = lang;
    updateTexts();
    document.getElementById('languageSelector').style.display = 'none';
    document.getElementById('modeSelector').style.display = 'block';
    GameAnalytics.languageChanged(lang);
    GameAnalytics.screenView('main_menu');
}

function updateTexts() {
    const t = translations[currentLang];
    document.getElementById('mainTitle').textContent = t.mainTitle;
    document.getElementById('mainSubtitle').textContent = t.mainSubtitle;
    document.getElementById('createRoomTitle').textContent = t.createRoomTitle;
    document.getElementById('createRoomDesc').textContent = t.createRoomDesc;
    document.getElementById('joinRoomTitle').textContent = t.joinRoomTitle;
    document.getElementById('joinRoomDesc').textContent = t.joinRoomDesc;
    document.getElementById('soloModeTitle').textContent = t.soloModeTitle;
    document.getElementById('soloModeDesc').textContent = t.soloModeDesc;
    document.getElementById('gameModeTitle').textContent = t.gameModeTitle;
    document.getElementById('simultaneousTitle').textContent = t.simultaneousTitle;
    document.getElementById('simultaneousDesc').textContent = t.simultaneousDesc;
    document.getElementById('turnBasedTitle').textContent = t.turnBasedTitle;
    document.getElementById('turnBasedDesc').textContent = t.turnBasedDesc;
    document.getElementById('joinTitle').textContent = t.joinTitle;
    document.getElementById('joinBtn').textContent = t.joinBtn;
    document.getElementById('backBtn1').textContent = t.backBtn;
    document.getElementById('backBtn2').textContent = t.backBtn;
    document.getElementById('backBtn3').textContent = t.backBtn;
    document.getElementById('roomCodeLabel').textContent = t.roomCodeLabel;
    document.getElementById('shareText').textContent = t.shareText;
    document.getElementById('copyBtn').textContent = t.copyBtn;
    document.getElementById('shareBtn').textContent = t.shareBtn;
    document.getElementById('waitingText').textContent = t.waitingText;
    document.getElementById('leaveBtn1').textContent = t.leaveBtn;
    document.getElementById('leaveBtn2').textContent = t.leaveBtn;
    document.getElementById('meLabel').textContent = t.meLabel;
    document.getElementById('opponentLabel').textContent = t.opponentLabel;
    document.getElementById('attemptsUnit1').textContent = t.attemptsUnit;
    document.getElementById('attemptsUnit2').textContent = t.attemptsUnit;
    document.getElementById('myStatus').textContent = t.myStatusPlaying;
    document.getElementById('opponentStatus').textContent = t.opponentStatusPlaying;
    document.getElementById('guessBtn1').textContent = t.guessBtn;
    document.getElementById('guessBtn2').textContent = t.guessBtn;
    document.getElementById('soloAttemptsLabel').textContent = t.soloAttemptsLabel;
    document.getElementById('newGameBtn').textContent = t.newGameBtn;
    document.getElementById('playAgainBtn').textContent = t.playAgainBtn;
    document.getElementById('closeModalBtn').textContent = t.closeModalBtn;
    document.getElementById('closeModalBtn2').textContent = t.closeModalBtn2;

    // League mode
    const leagueModeTitle = document.getElementById('leagueModeTitle');
    if (leagueModeTitle) leagueModeTitle.textContent = t.leagueModeTitle;
    const leagueModeDesc = document.getElementById('leagueModeDesc');
    if (leagueModeDesc) leagueModeDesc.textContent = t.leagueModeDesc;
    const leagueTitle = document.getElementById('leagueTitle');
    if (leagueTitle) leagueTitle.textContent = t.leagueTitle;
    const leagueDesc = document.getElementById('leagueDesc');
    if (leagueDesc) leagueDesc.textContent = t.leagueDesc;
    const leagueBackBtn = document.getElementById('leagueBackBtn');
    if (leagueBackBtn) leagueBackBtn.textContent = t.leagueBackBtn;
    const leagueLeaveBtn = document.getElementById('leagueLeaveBtn');
    if (leagueLeaveBtn) leagueLeaveBtn.textContent = t.leagueLeaveBtn;
    const leagueGuessBtn = document.getElementById('leagueGuessBtn');
    if (leagueGuessBtn) leagueGuessBtn.textContent = t.leagueGuessBtn;
    const leagueMeLabel = document.getElementById('leagueMeLabel');
    if (leagueMeLabel) leagueMeLabel.textContent = t.leagueMeLabel;
    const leagueTryAgainBtn = document.getElementById('leagueTryAgainBtn');
    if (leagueTryAgainBtn) leagueTryAgainBtn.textContent = t.leagueTryAgainBtn;
    const leagueBackToLevelsBtn = document.getElementById('leagueBackToLevelsBtn');
    if (leagueBackToLevelsBtn) leagueBackToLevelsBtn.textContent = t.leagueBackToLevelsBtn;
    const leagueAttemptsUnit1 = document.getElementById('leagueAttemptsUnit1');
    if (leagueAttemptsUnit1) leagueAttemptsUnit1.textContent = t.attemptsUnit;
    const leagueAttemptsUnit2 = document.getElementById('leagueAttemptsUnit2');
    if (leagueAttemptsUnit2) leagueAttemptsUnit2.textContent = t.attemptsUnit;
    const leagueMyStatus = document.getElementById('leagueMyStatus');
    if (leagueMyStatus) leagueMyStatus.textContent = t.myStatusPlaying;
    const leagueCpuStatus = document.getElementById('leagueCpuStatus');
    if (leagueCpuStatus) leagueCpuStatus.textContent = t.opponentStatusPlaying;

    // How to Play
    const setText = (id, key) => {
        const el = document.getElementById(id);
        if (el) el.textContent = t[key];
    };
    setText('helpLinkBtn', 'helpLinkBtn');
    setText('helpTitle', 'help.title');
    setText('helpGoal', 'help.goal');
    setText('helpGoalDesc', 'help.goalDesc');
    setText('helpFeedback', 'help.feedback');
    setText('helpStrikeDesc', 'help.strikeDesc');
    setText('helpBallDesc', 'help.ballDesc');
    setText('helpOutDesc', 'help.outDesc');
    setText('helpRules', 'help.rules');
    setText('helpRule1', 'help.rule1');
    setText('helpRule2', 'help.rule2');
    setText('helpRule3', 'help.rule3');
    setText('helpExample', 'help.example');
    setText('helpExampleTitle', 'help.exampleTitle');
    setText('helpEx1', 'help.ex1');
    setText('helpEx2', 'help.ex2');
    setText('helpEx3', 'help.ex3');
    setText('helpEx4', 'help.ex4');
    setText('helpEx5', 'help.ex5');
    setText('helpEx6', 'help.ex6');
    setText('helpCloseBtn', 'helpCloseBtn');
}

function getText(key, replacements = {}) {
    let text = translations[currentLang][key];
    for (const [k, v] of Object.entries(replacements)) {
        text = text.replace(`{${k}}`, v);
    }
    return text;
}
