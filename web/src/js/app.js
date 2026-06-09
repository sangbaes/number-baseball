// Navigation, modal control, input handlers, deep-link.

function closeModal() {
    document.getElementById('resultModal').classList.remove('show');
    if (gameMode === 'multiplayer') {
        leaveRoom();
    } else {
        backToMode();
    }
}

function backToMode() {
    roomCode = '';
    isHost = false;
    answer = '';
    attempts = 0;
    gameEnded = false;
    gameMode = '';
    multiplayerMode = '';
    currentTurn = '';
    opponentId = '';

    // Reset any in-flight league match too.
    if (typeof leagueState !== 'undefined') leagueState = null;
    if (typeof cpuThinkingTimer !== 'undefined' && cpuThinkingTimer) {
        clearTimeout(cpuThinkingTimer);
        cpuThinkingTimer = null;
    }

    document.getElementById('historyMulti').innerHTML = '';
    document.getElementById('historySolo').innerHTML = '';
    document.getElementById('leagueHistory').innerHTML = '';
    document.getElementById('guessInputMulti').value = '';
    document.getElementById('guessInputSolo').value = '';
    document.getElementById('leagueGuessInput').value = '';
    document.getElementById('resultModal').classList.remove('show');

    hideAllSections();
    document.getElementById('modeSelector').style.display = 'block';
}

function hideAllSections() {
    document.getElementById('languageSelector').style.display = 'none';
    document.getElementById('modeSelector').style.display = 'none';
    document.getElementById('gameModeSelection').style.display = 'none';
    document.getElementById('joinSection').style.display = 'none';
    document.getElementById('waitingRoom').style.display = 'none';
    document.getElementById('multiplayerGame').style.display = 'none';
    document.getElementById('soloGame').style.display = 'none';
    document.getElementById('leagueHome').style.display = 'none';
    document.getElementById('leagueGame').style.display = 'none';
}

// Deep-link: ?room=ABC123 jumps straight to join.
window.addEventListener('load', () => {
    const params = new URLSearchParams(window.location.search);
    const roomParam = params.get('room');
    if (roomParam) {
        setLanguage('ko');
        document.getElementById('roomCodeInput').value = roomParam;
        showJoinRoom();
    }
});

// Numeric-only input, max 3 digits.
document.getElementById('guessInputMulti').addEventListener('input', function () {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 3);
});

document.getElementById('guessInputSolo').addEventListener('input', function () {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 3);
});

document.getElementById('leagueGuessInput').addEventListener('input', function () {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 3);
});

// Enter to submit.
document.getElementById('guessInputMulti').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') makeGuessMulti();
});

document.getElementById('guessInputSolo').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') makeGuessSolo();
});

document.getElementById('leagueGuessInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') makeLeagueGuess();
});

document.getElementById('roomCodeInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') joinRoom();
});
