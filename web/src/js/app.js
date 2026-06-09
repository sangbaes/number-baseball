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

    document.getElementById('historyMulti').innerHTML = '';
    document.getElementById('historySolo').innerHTML = '';
    document.getElementById('guessInputMulti').value = '';
    document.getElementById('guessInputSolo').value = '';
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

// Enter to submit.
document.getElementById('guessInputMulti').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') makeGuessMulti();
});

document.getElementById('guessInputSolo').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') makeGuessSolo();
});

document.getElementById('roomCodeInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') joinRoom();
});
