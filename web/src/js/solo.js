// Solo (single-player) mode.
// Depends on globals from i18n.js, baseball-logic.js, firebase-config.js.

function startSoloMode() {
    gameMode = 'solo';
    answer = generateNumber();
    attempts = 0;
    gameEnded = false;

    hideAllSections();
    document.getElementById('soloGame').style.display = 'block';
    document.getElementById('attemptCount').textContent = '0';
    document.getElementById('historySolo').innerHTML = '';
    document.getElementById('guessInputSolo').value = '';
    document.getElementById('guessInputSolo').focus();

    GameAnalytics.screenView('solo_game');
    GameAnalytics.soloGameStarted();
}

function makeGuessSolo() {
    if (gameEnded) return;

    const input = document.getElementById('guessInputSolo');
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
    document.getElementById('attemptCount').textContent = attempts;
    GameAnalytics.guessSubmitted(attempts);

    const result = calculateResult(answer, guess);
    const resultStr = formatResult(result.strike, result.ball);

    addHistorySolo(guess, resultStr);

    if (result.strike === 3) {
        gameEnded = true;
        GameAnalytics.soloGameWon(attempts);
        setTimeout(() => showSoloResult(true), 500);
    } else if (attempts >= 30) {
        gameEnded = true;
        GameAnalytics.soloGameLost();
        setTimeout(() => showSoloResult(false), 500);
    }

    input.value = '';
    input.focus();
}

function addHistorySolo(guess, result) {
    const historyEl = document.getElementById('historySolo');
    const item = document.createElement('div');
    item.className = 'history-item';
    item.innerHTML = `
        <span class="guess-number">${guess}</span>
        <span class="result">${result}</span>
    `;
    historyEl.insertBefore(item, historyEl.firstChild);
}

function showSoloResult(won) {
    const modal = document.getElementById('resultModal');
    const emoji = document.getElementById('resultEmoji');
    const text = document.getElementById('resultText');
    const detail = document.getElementById('resultDetail');

    if (won) {
        emoji.textContent = '🎉';
        text.textContent = getText('soloWinTitle');
        detail.textContent = getText('soloWinDetail', { attempts: attempts, answer: answer });
    } else {
        emoji.textContent = '😢';
        text.textContent = getText('soloLoseTitle');
        detail.textContent = getText('soloLoseDetail', { answer: answer });
    }

    document.getElementById('multiplayerButtons').style.display = 'none';
    document.getElementById('soloButton').style.display = 'block';
    const lb = document.getElementById('leagueButtons');
    if (lb) lb.style.display = 'none';
    modal.classList.add('show');
}

function newSoloGame() {
    startSoloMode();
}
