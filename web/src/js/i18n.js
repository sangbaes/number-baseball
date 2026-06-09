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
        codeCopied: "코드가 복사되었습니다: ",
        shareMessage: "숫자야구 게임에 초대합니다!\n방 코드: {code}\n\n링크로 바로 입장하기:\n{url}?room={code}"
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
        codeCopied: "Code copied: ",
        shareMessage: "Join my Number Baseball game!\nRoom Code: {code}\n\nDirect link:\n{url}?room={code}"
    }
};

let currentLang = 'ko';

function setLanguage(lang) {
    currentLang = lang;
    updateTexts();
    document.getElementById('languageSelector').style.display = 'none';
    document.getElementById('modeSelector').style.display = 'block';
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
}

function getText(key, replacements = {}) {
    let text = translations[currentLang][key];
    for (const [k, v] of Object.entries(replacements)) {
        text = text.replace(`{${k}}`, v);
    }
    return text;
}
