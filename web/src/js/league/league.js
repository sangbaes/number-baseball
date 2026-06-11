// League mode — user vs local CPU, turn-based, 5 difficulty tiers.
// All in-memory; no Firebase rooms.
// Depends on: i18n.js, baseball-logic.js, strategy.js.
// Single shared secret (both race to guess) — see startLeagueMatch.

console.log('[baseball] league.js v4.3 loaded — monospace digits + aligned columns');

// ---------- Local progression (localStorage) ----------

const _UNLOCK_KEY = 'baseballLeagueUnlocked';

function getUnlockedLevel() {
    const v = parseInt(localStorage.getItem(_UNLOCK_KEY) || '1', 10);
    return Number.isFinite(v) && v >= 1 ? Math.min(v, 5) : 1;
}

function bumpUnlockedLevel(clearedLevel) {
    const next = Math.min(clearedLevel + 1, 5);
    const current = getUnlockedLevel();
    if (next > current) {
        localStorage.setItem(_UNLOCK_KEY, String(next));
    }
}

// ---------- League home screen ----------

function showLeagueHome() {
    hideAllSections();
    document.getElementById('leagueHome').style.display = 'block';
    renderLevelCards();
    GameAnalytics.screenView('league_home');
}

function renderLevelCards() {
    const container = document.getElementById('leagueLevels');
    const unlocked = getUnlockedLevel();
    container.innerHTML = '';

    for (let level = 1; level <= 5; level++) {
        const cfg = LEAGUE_LEVEL_CONFIGS[level];
        const isUnlocked = level <= unlocked;
        const localName = getText(`league.levelName.${level}`) || cfg.name;
        const localizedLabel = getText('league.level', { n: level });

        const card = document.createElement('div');
        card.className = 'level-card level-card-' + level + (isUnlocked ? '' : ' locked');
        card.innerHTML = `
            <div class="level-card-icon">${cfg.emoji}</div>
            <div class="level-card-body">
                <div class="level-card-title">
                    <span class="level-card-name">${localizedLabel}</span>
                    <span class="level-card-tier">${localName}</span>
                </div>
                <div class="level-card-status">${
                    isUnlocked
                        ? getText('league.readyToPlay')
                        : getText('league.needWin', { n: level - 1 })
                }</div>
            </div>
            <div class="level-card-arrow">${isUnlocked ? '▶' : '🔒'}</div>
        `;
        if (isUnlocked) {
            card.addEventListener('click', () => startLeagueMatch(level));
        }
        container.appendChild(card);
    }
}

// ---------- League game state ----------

let leagueState = null;
let cpuThinkingTimer = null;

function startLeagueMatch(level) {
    const cfg = LEAGUE_LEVEL_CONFIGS[level];
    const cpuStrategy = makeCPUStrategy(level);

    // Single shared secret — both sides race to guess it.
    // Mirrors iOS CPUPlayer.swift which uses svc.turnSecret for both p1 and p2.
    // CPU (p1) starts first, matching RoomService.createLocalCPURoom:
    //   "rooms/\(roomCode)/currentTurn": "p1"
    leagueState = {
        level,
        cfg,
        cpuStrategy,
        secret: generateNumber(),
        userHistory: [],   // user's own guesses + (s,b) against secret
        cpuHistory: [],    // cpu's own guesses + (s,b) against secret
        turn: 'cpu',
        ended: false,
        userWon: false,
    };

    gameMode = 'league';
    hideAllSections();
    document.getElementById('leagueGame').style.display = 'block';

    document.getElementById('leagueCpuName').textContent = cfg.cpuName;
    document.getElementById('leagueMyAttempts').textContent = '0';
    document.getElementById('leagueCpuAttempts').textContent = '0';
    document.getElementById('leagueMyStatus').textContent = getText('myStatusPlaying');
    document.getElementById('leagueCpuStatus').textContent = getText('opponentStatusPlaying');
    document.getElementById('leagueMyLastGuess').textContent = '';
    document.getElementById('leagueCpuLastGuess').textContent = '';
    document.getElementById('leagueHistory').innerHTML = '';
    document.getElementById('leagueGuessInput').value = '';

    updateLeagueTurnDisplay();
    // Mirror iOS ProgressionManager: league match counted as roomJoined with
    // a per-level method tag so analytics differentiates levels.
    GameAnalytics.screenView('league_game');
    GameAnalytics.roomJoined('league_level_' + level);

    // CPU starts (matches iOS). Schedule its first guess; user input regains
    // focus inside runCPUTurn after CPU plays.
    scheduleCPUTurn();
}

function updateLeagueTurnDisplay() {
    if (!leagueState) return;
    const turnInfo = document.getElementById('leagueTurnInfo');
    const turnText = document.getElementById('leagueTurnText');
    const btn = document.getElementById('leagueGuessBtn');
    const input = document.getElementById('leagueGuessInput');
    const myTurn = leagueState.turn === 'user';
    turnInfo.style.display = 'block';
    if (myTurn) {
        turnText.textContent = getText('yourTurn');
        btn.disabled = false;
        input.disabled = false;
    } else {
        turnText.textContent = getText('league.cpuThinking', { cpu: leagueState.cfg.cpuName });
        btn.disabled = true;
        input.disabled = true;
    }
}

function makeLeagueGuess() {
    if (!leagueState || leagueState.ended || leagueState.turn !== 'user') return;

    const input = document.getElementById('leagueGuessInput');
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

    const { strike, ball } = calculateResult(leagueState.secret, guess);
    const resultStr = formatResult(strike, ball);

    leagueState.userHistory.push({ guess, strike, ball });
    GameAnalytics.guessSubmitted(leagueState.userHistory.length);
    addLeagueHistoryRow('user', guess, resultStr);

    document.getElementById('leagueMyAttempts').textContent = leagueState.userHistory.length;
    document.getElementById('leagueMyLastGuess').textContent = `${guess} → ${resultStr}`;

    input.value = '';

    if (strike === 3) {
        endLeagueMatch(true);
        return;
    }

    leagueState.turn = 'cpu';
    updateLeagueTurnDisplay();
    scheduleCPUTurn();
}

function scheduleCPUTurn() {
    if (!leagueState || leagueState.ended) return;
    const delay = leagueState.cfg.delayMs + Math.floor(Math.random() * 400);
    clearTimeout(cpuThinkingTimer);
    cpuThinkingTimer = setTimeout(runCPUTurn, delay);
}

function runCPUTurn() {
    if (!leagueState || leagueState.ended || leagueState.turn !== 'cpu') return;

    // Level 4+ peeks at the user's guesses too (same secret, so they're useful info).
    // Mirrors CPUPlayer.swift `if self.currentLevel >= 4`.
    let effectiveHistory = leagueState.cpuHistory;
    if (leagueState.level >= 4) {
        effectiveHistory = effectiveHistory.concat(leagueState.userHistory);
    }

    const guess = leagueState.cpuStrategy(effectiveHistory);
    const { strike, ball } = calculateResult(leagueState.secret, guess);
    const resultStr = formatResult(strike, ball);

    leagueState.cpuHistory.push({ guess, strike, ball });
    addLeagueHistoryRow('cpu', guess, resultStr);

    document.getElementById('leagueCpuAttempts').textContent = leagueState.cpuHistory.length;
    document.getElementById('leagueCpuLastGuess').textContent = `${guess} → ${resultStr}`;

    if (strike === 3) {
        endLeagueMatch(false);
        return;
    }

    leagueState.turn = 'user';
    updateLeagueTurnDisplay();
    document.getElementById('leagueGuessInput').focus();
}

function addLeagueHistoryRow(actor, guess, result) {
    const list = document.getElementById('leagueHistory');
    const item = document.createElement('div');
    item.className = 'history-item history-item-' + actor;
    const label = actor === 'user' ? getText('league.youLabel') : (leagueState?.cfg.cpuName || 'CPU');
    item.innerHTML = `
        <span class="history-actor">${label}</span>
        <span class="guess-number">${guess}</span>
        <span class="result">${result}</span>
    `;
    list.insertBefore(item, list.firstChild);
}

function endLeagueMatch(userWon) {
    if (!leagueState) return;
    leagueState.ended = true;
    leagueState.userWon = userWon;
    clearTimeout(cpuThinkingTimer);

    if (userWon) {
        bumpUnlockedLevel(leagueState.level);
        GameAnalytics.gameWon('league', leagueState.userHistory.length);
    } else {
        GameAnalytics.gameLost('league', leagueState.userHistory.length);
    }

    const modal = document.getElementById('resultModal');
    const emoji = document.getElementById('resultEmoji');
    const text = document.getElementById('resultText');
    const detail = document.getElementById('resultDetail');

    if (userWon) {
        emoji.textContent = '🏆';
        text.textContent = getText('league.winTitle');
        const nextLevel = Math.min(leagueState.level + 1, 5);
        const unlockedMsg = leagueState.level < 5
            ? '\n' + getText('league.unlockedNext', { n: nextLevel })
            : '\n' + getText('league.allCleared');
        detail.textContent = getText('league.winDetail', {
            level: leagueState.level,
            cpu: leagueState.cfg.cpuName,
            attempts: leagueState.userHistory.length,
        }) + unlockedMsg;
    } else {
        emoji.textContent = '😢';
        text.textContent = getText('league.loseTitle');
        detail.textContent = getText('league.loseDetail', {
            level: leagueState.level,
            cpu: leagueState.cfg.cpuName,
            attempts: leagueState.cpuHistory.length,
            answer: leagueState.secret,
        });
    }

    document.getElementById('multiplayerButtons').style.display = 'none';
    document.getElementById('soloButton').style.display = 'none';
    document.getElementById('leagueButtons').style.display = 'block';

    // Primary button:
    //   win + next level available → "Next Challenge →"
    //   win + final level cleared  → hide (only "Back to Levels" remains)
    //   loss                       → "Try Again" (same level)
    const primaryBtn = document.getElementById('leagueTryAgainBtn');
    if (userWon && leagueState.level < 5) {
        primaryBtn.textContent = getText('leagueNextChallengeBtn');
        primaryBtn.style.display = '';
    } else if (userWon) {
        primaryBtn.style.display = 'none';
    } else {
        primaryBtn.textContent = getText('leagueTryAgainBtn');
        primaryBtn.style.display = '';
    }

    modal.classList.add('show');
}

function leagueTryAgain() {
    document.getElementById('resultModal').classList.remove('show');
    if (!leagueState) return;
    // Win → advance to next level; loss → retry same level.
    const goNext = leagueState.userWon && leagueState.level < 5;
    const targetLevel = goNext ? leagueState.level + 1 : leagueState.level;
    startLeagueMatch(targetLevel);
}

function leagueBackToLevels() {
    document.getElementById('resultModal').classList.remove('show');
    clearTimeout(cpuThinkingTimer);
    leagueState = null;
    gameMode = '';
    showLeagueHome();
}

function leaveLeague() {
    clearTimeout(cpuThinkingTimer);
    leagueState = null;
    gameMode = '';
    showLeagueHome();
}
