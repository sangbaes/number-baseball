// CPU strategies — ports of CPUStrategy.swift.
// Pure logic, no DOM, no Firebase. Exposes globals:
//   LEAGUE_LEVEL_CONFIGS, makeCPUStrategy(level)
//
// A strategy is a function `(history) -> guess` where
//   history = [{ guess: "123", strike: 1, ball: 2 }, ...]
// Each call returns the next 3-digit guess as a string.

// 720 = 10 * 9 * 8 permutations of distinct digits.
const ALL_CANDIDATES = (() => {
    const out = [];
    for (let a = 0; a < 10; a++) {
        for (let b = 0; b < 10; b++) {
            if (b === a) continue;
            for (let c = 0; c < 10; c++) {
                if (c === a || c === b) continue;
                out.push(`${a}${b}${c}`);
            }
        }
    }
    return out;
})();

function _strikeBall(secret, guess) {
    let s = 0, b = 0;
    for (let i = 0; i < 3; i++) {
        if (guess[i] === secret[i]) s++;
        else if (secret.includes(guess[i])) b++;
    }
    return { s, b };
}

function _filterConsistent(candidates, guess, strike, ball) {
    return candidates.filter(c => {
        const { s, b } = _strikeBall(c, guess);
        return s === strike && b === ball;
    });
}

function _shuffle(arr) {
    const out = arr.slice();
    for (let i = out.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
}

function _consistentWith(history) {
    let pool = ALL_CANDIDATES;
    for (const h of history) {
        pool = _filterConsistent(pool, h.guess, h.strike, h.ball);
    }
    return pool;
}

// ---------- Strategies ----------

function randomStrategy(_history) {
    return ALL_CANDIDATES[Math.floor(Math.random() * ALL_CANDIDATES.length)];
}

function eliminationStrategy(history) {
    const pool = _consistentWith(history);
    if (pool.length === 0) return randomStrategy(history);
    return pool[Math.floor(Math.random() * pool.length)];
}

function entropyStrategy(history) {
    const pool = _consistentWith(history);
    if (pool.length === 0) return randomStrategy(history);
    if (pool.length <= 2) return pool[Math.floor(Math.random() * pool.length)];

    const poolSet = new Set(pool);

    // Evaluate all remaining candidates + up to 100 sampled outsiders.
    let guessesToEval = pool.slice();
    const others = ALL_CANDIDATES.filter(c => !poolSet.has(c));
    if (others.length > 100) {
        guessesToEval = guessesToEval.concat(_shuffle(others).slice(0, 100));
    } else {
        guessesToEval = guessesToEval.concat(others);
    }

    let bestGuess = null;
    let bestEntropy = -1;
    let bestIsCandidate = false;

    for (const g of guessesToEval) {
        const counter = new Map();
        for (const c of pool) {
            const { s, b } = _strikeBall(c, g);
            const key = s * 10 + b;
            counter.set(key, (counter.get(key) || 0) + 1);
        }
        const total = pool.length;
        let entropy = 0;
        for (const count of counter.values()) {
            if (count > 0) {
                const p = count / total;
                entropy -= p * Math.log2(p);
            }
        }
        const isCandidate = poolSet.has(g);
        if (entropy > bestEntropy || (entropy === bestEntropy && isCandidate && !bestIsCandidate)) {
            bestEntropy = entropy;
            bestGuess = g;
            bestIsCandidate = isCandidate;
        }
    }

    return bestGuess || pool[0];
}

function minimaxStrategy(history) {
    const pool = _consistentWith(history);
    if (pool.length === 0) return randomStrategy(history);
    if (pool.length <= 2) return pool[0];

    const poolSet = new Set(pool);
    let bestGuess = null;
    let bestWorst = Infinity;
    let bestIsCandidate = false;

    for (const g of ALL_CANDIDATES) {
        const counter = new Map();
        for (const c of pool) {
            const { s, b } = _strikeBall(c, g);
            const key = s * 10 + b;
            counter.set(key, (counter.get(key) || 0) + 1);
        }
        let worst = 0;
        for (const count of counter.values()) {
            if (count > worst) worst = count;
        }
        const isCandidate = poolSet.has(g);
        if (worst < bestWorst || (worst === bestWorst && isCandidate && !bestIsCandidate)) {
            bestWorst = worst;
            bestGuess = g;
            bestIsCandidate = isCandidate;
        }
    }

    return bestGuess || pool[0];
}

function _withNoise(strategy, errorRate) {
    return (history) => {
        if (Math.random() < errorRate) {
            return randomStrategy(history);
        }
        return strategy(history);
    };
}

// ---------- Level configs ----------
// Mirrors CPUPlayer.levelConfigs but with shorter web-tuned delays.

const LEAGUE_LEVEL_CONFIGS = {
    1: { strategy: 'random',      errorRate: 0.0,  delayMs: 800, name: 'Beginner',     emoji: '🥉', cpuName: 'CPU-Beginner' },
    2: { strategy: 'elimination', errorRate: 0.4,  delayMs: 700, name: 'Intermediate', emoji: '🥈', cpuName: 'CPU-Intermediate' },
    3: { strategy: 'elimination', errorRate: 0.0,  delayMs: 600, name: 'Advanced',     emoji: '🥇', cpuName: 'CPU-Advanced' },
    4: { strategy: 'entropy',     errorRate: 0.15, delayMs: 500, name: 'Expert',       emoji: '💎', cpuName: 'CPU-Expert' },
    5: { strategy: 'entropy',     errorRate: 0.0,  delayMs: 450, name: 'Master',       emoji: '👑', cpuName: 'CPU-Master' },
};

function makeCPUStrategy(level) {
    const cfg = LEAGUE_LEVEL_CONFIGS[level] || LEAGUE_LEVEL_CONFIGS[1];
    let base;
    switch (cfg.strategy) {
        case 'elimination': base = eliminationStrategy; break;
        case 'entropy':     base = entropyStrategy; break;
        case 'minimax':     base = minimaxStrategy; break;
        default:            base = randomStrategy;
    }
    return cfg.errorRate > 0 ? _withNoise(base, cfg.errorRate) : base;
}
