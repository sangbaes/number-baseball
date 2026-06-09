// Multiplayer mode (Firebase Realtime Database).
// Depends on globals from i18n.js, baseball-logic.js, firebase-config.js.

function showGameModeSelection(_action) {
    hideAllSections();
    document.getElementById('gameModeSelection').style.display = 'block';
}

function createRoom(mode) {
    gameMode = 'multiplayer';
    multiplayerMode = mode;
    roomCode = generateRoomCode();
    isHost = true;
    answer = generateNumber();
    gameEnded = false;
    attempts = 0;

    const roomRef = database.ref('rooms/' + roomCode);
    const roomData = {
        answer: answer,
        host: playerId,
        status: 'waiting',
        gameMode: mode,
        players: {
            [playerId]: { attempts: 0, status: 'waiting', isWinner: false }
        },
        createdAt: Date.now()
    };

    if (mode === 'turn-based') {
        roomData.currentTurn = playerId;
        roomData.turnOrder = [playerId];
    }

    roomRef.set(roomData);

    showWaitingRoom();
    listenToRoom();
}

function showJoinRoom() {
    hideAllSections();
    document.getElementById('joinSection').style.display = 'block';
}

function joinRoom() {
    const input = document.getElementById('roomCodeInput').value.toUpperCase();
    if (input.length !== 6) {
        alert(getText('errorRoomCode'));
        return;
    }

    gameMode = 'multiplayer';
    roomCode = input;
    gameEnded = false;
    attempts = 0;
    const roomRef = database.ref('rooms/' + roomCode);

    roomRef.once('value').then((snapshot) => {
        if (!snapshot.exists()) {
            alert(getText('errorNoRoom'));
            return;
        }

        const roomData = snapshot.val();
        if (roomData.status !== 'waiting') {
            alert(getText('errorStarted'));
            return;
        }

        answer = roomData.answer;
        multiplayerMode = roomData.gameMode || 'simultaneous';

        roomRef.child('players/' + playerId).set({
            attempts: 0,
            status: 'ready',
            isWinner: false
        });

        if (multiplayerMode === 'turn-based') {
            roomRef.child('turnOrder').once('value').then(orderSnapshot => {
                const turnOrder = orderSnapshot.val() || [];
                turnOrder.push(playerId);
                roomRef.update({ turnOrder: turnOrder });
            });
        }

        roomRef.update({ status: 'playing' });

        showMultiplayerGame();
        listenToRoom();
    });
}

function showWaitingRoom() {
    hideAllSections();
    document.getElementById('waitingRoom').style.display = 'block';
    document.getElementById('displayRoomCode').textContent = roomCode;
}

function showMultiplayerGame() {
    hideAllSections();
    document.getElementById('multiplayerGame').style.display = 'block';
    document.getElementById('myAttempts').textContent = '0';
    document.getElementById('opponentAttempts').textContent = '0';
    document.getElementById('historyMulti').innerHTML = '';
    document.getElementById('guessInputMulti').value = '';

    if (multiplayerMode === 'turn-based') {
        updateTurnDisplay();
    }

    document.getElementById('guessInputMulti').focus();
}

function listenToRoom() {
    const roomRef = database.ref('rooms/' + roomCode);

    roomRef.on('value', (snapshot) => {
        const data = snapshot.val();
        if (!data) return;

        if (data.gameMode) {
            multiplayerMode = data.gameMode;
        }

        if (multiplayerMode === 'turn-based' && data.currentTurn) {
            currentTurn = data.currentTurn;
            updateTurnDisplay();
        }

        if (data.status === 'playing' && document.getElementById('waitingRoom').style.display === 'block') {
            showMultiplayerGame();
        }

        updatePlayerStatus(data.players);
    });
}

function updatePlayerStatus(players) {
    let myData = null;
    let opponentData = null;

    for (const pid in players) {
        if (pid === playerId) {
            myData = players[pid];
        } else {
            opponentData = players[pid];
            opponentId = pid;
        }
    }

    if (myData) {
        document.getElementById('myAttempts').textContent = myData.attempts;

        if (myData.lastGuess && myData.lastResult) {
            document.getElementById('myLastGuess').textContent =
                `${myData.lastGuess} → ${myData.lastResult}`;
        }

        if (myData.isWinner) {
            document.getElementById('myStatus').textContent = getText('myStatusWin');
            if (!gameEnded) {
                gameEnded = true;
                showMultiResult(true, myData.attempts, opponentData?.attempts || 0);
            }
        }
    }

    if (opponentData) {
        document.getElementById('opponentAttempts').textContent = opponentData.attempts;

        if (opponentData.lastGuess && opponentData.lastResult) {
            const lastGuessEl = document.getElementById('opponentLastGuess');
            lastGuessEl.textContent = `${opponentData.lastGuess} → ${opponentData.lastResult}`;

            if (multiplayerMode === 'turn-based') {
                lastGuessEl.style.fontWeight = 'bold';
                lastGuessEl.style.color = '#e74c3c';
            }
        }

        if (opponentData.isWinner) {
            document.getElementById('opponentStatus').textContent = getText('opponentStatusWin');
            if (!gameEnded) {
                gameEnded = true;
                showMultiResult(false, myData.attempts, opponentData.attempts);
            }
        }
    }
}

function updateTurnDisplay() {
    const turnInfo = document.getElementById('turnInfo');
    const turnText = document.getElementById('turnText');
    const guessBtn = document.getElementById('guessBtn1');
    const guessInput = document.getElementById('guessInputMulti');

    if (multiplayerMode === 'turn-based') {
        turnInfo.style.display = 'block';
        if (currentTurn === playerId) {
            turnText.textContent = getText('yourTurn');
            turnText.style.color = '#f5ead6';
            guessBtn.disabled = false;
            guessInput.disabled = false;
        } else {
            turnText.textContent = getText('opponentTurn');
            turnText.style.color = '#e74c3c';
            guessBtn.disabled = true;
            guessInput.disabled = true;
        }
    } else {
        turnInfo.style.display = 'none';
        guessBtn.disabled = false;
        guessInput.disabled = false;
    }
}

function makeGuessMulti() {
    if (gameEnded) return;

    if (multiplayerMode === 'turn-based' && currentTurn !== playerId) {
        alert(getText('errorNotYourTurn'));
        return;
    }

    const input = document.getElementById('guessInputMulti');
    const guess = input.value.trim().replace(/[^0-9]/g, '');

    if (guess.length !== 3 || !/^\d{3}$/.test(guess)) {
        alert(getText('errorDigits'));
        input.value = '';
        return;
    }

    if (new Set(guess).size !== 3) {
        alert(getText('errorRepeating'));
        input.value = '';
        return;
    }

    attempts++;
    const result = calculateResult(answer, guess);
    const resultStr = formatResult(result.strike, result.ball);

    addHistoryMulti(guess, resultStr);

    const roomRef = database.ref('rooms/' + roomCode + '/players/' + playerId);
    roomRef.update({
        attempts: attempts,
        lastGuess: guess,
        lastResult: resultStr
    });

    if (result.strike === 3) {
        roomRef.update({ isWinner: true });
    } else if (multiplayerMode === 'turn-based') {
        switchTurn();
    }

    input.value = '';
    input.focus();
}

function switchTurn() {
    const roomRef = database.ref('rooms/' + roomCode);
    roomRef.child('turnOrder').once('value').then(snapshot => {
        const turnOrder = snapshot.val() || [];
        const currentIndex = turnOrder.indexOf(currentTurn);
        const nextIndex = (currentIndex + 1) % turnOrder.length;
        const nextTurn = turnOrder[nextIndex];
        roomRef.update({ currentTurn: nextTurn });
    });
}

function addHistoryMulti(guess, result) {
    const historyEl = document.getElementById('historyMulti');
    const item = document.createElement('div');
    item.className = 'history-item';
    item.innerHTML = `
        <span class="guess-number">${guess}</span>
        <span class="result">${result}</span>
    `;
    historyEl.insertBefore(item, historyEl.firstChild);
}

function showMultiResult(won, myAttempts, opponentAttempts) {
    const modal = document.getElementById('resultModal');
    const emoji = document.getElementById('resultEmoji');
    const text = document.getElementById('resultText');
    const detail = document.getElementById('resultDetail');

    if (won) {
        emoji.textContent = '🎉';
        text.textContent = getText('winTitle');
        detail.textContent = getText('winDetail', { attempts: myAttempts });
    } else {
        emoji.textContent = '😢';
        text.textContent = getText('loseTitle');
        detail.textContent = getText('loseDetail', { attempts: opponentAttempts });
    }

    document.getElementById('multiplayerButtons').style.display = 'block';
    document.getElementById('soloButton').style.display = 'none';
    const lb = document.getElementById('leagueButtons');
    if (lb) lb.style.display = 'none';
    modal.classList.add('show');
}

function playAgain() {
    document.getElementById('resultModal').classList.remove('show');

    answer = generateNumber();
    attempts = 0;
    gameEnded = false;

    const roomRef = database.ref('rooms/' + roomCode);
    roomRef.update({
        answer: answer,
        currentTurn: multiplayerMode === 'turn-based' ? (isHost ? playerId : opponentId) : null
    });

    const playerRef = roomRef.child('players/' + playerId);
    playerRef.update({
        attempts: 0,
        isWinner: false,
        lastGuess: null,
        lastResult: null
    });

    document.getElementById('myAttempts').textContent = '0';
    document.getElementById('opponentAttempts').textContent = '0';
    document.getElementById('myStatus').textContent = getText('myStatusPlaying');
    document.getElementById('opponentStatus').textContent = getText('opponentStatusPlaying');
    document.getElementById('myLastGuess').textContent = '';
    document.getElementById('opponentLastGuess').textContent = '';
    document.getElementById('historyMulti').innerHTML = '';
    document.getElementById('guessInputMulti').value = '';

    if (multiplayerMode === 'turn-based') {
        updateTurnDisplay();
    }

    document.getElementById('guessInputMulti').focus();
}

function copyRoomCode() {
    navigator.clipboard.writeText(roomCode).then(() => {
        alert(getText('codeCopied') + roomCode);
    });
}

function shareRoomCode() {
    const text = getText('shareMessage', {
        code: roomCode,
        url: window.location.href.split('?')[0]
    });

    if (navigator.share) {
        navigator.share({
            title: getText('mainTitle'),
            text: text
        });
    } else {
        copyRoomCode();
    }
}

function leaveRoom() {
    if (roomCode) {
        database.ref('rooms/' + roomCode + '/players/' + playerId).remove();
    }
    backToMode();
}
