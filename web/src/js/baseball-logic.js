// Pure game logic — no DOM, no Firebase.
// Exposes globals: generateNumber(), generateRoomCode(), calculateResult(), formatResult().

function generateNumber() {
    const digits = [];
    while (digits.length < 3) {
        const digit = Math.floor(Math.random() * 10);
        if (!digits.includes(digit)) {
            digits.push(digit);
        }
    }
    return digits.join('');
}

function generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

function calculateResult(answer, guess) {
    let strike = 0;
    let ball = 0;
    for (let i = 0; i < 3; i++) {
        if (guess[i] === answer[i]) {
            strike++;
        } else if (answer.includes(guess[i])) {
            ball++;
        }
    }
    return { strike, ball };
}

function formatResult(strike, ball) {
    if (strike === 0 && ball === 0) return '0';
    const parts = [];
    if (strike > 0) parts.push(`${strike}S`);
    if (ball > 0) parts.push(`${ball}B`);
    return parts.join(' ');
}
