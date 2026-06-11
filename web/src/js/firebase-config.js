// Firebase init.
// Exposes globals: app, database, playerId (per-tab unique id), and shared game state vars.

const firebaseConfig = {
    apiKey: "AIzaSyCZqGq1dGKCZESJcqOcNlwwGtWrHld2R3k",
    authDomain: "number-baseball-28392.firebaseapp.com",
    databaseURL: "https://number-baseball-28392-default-rtdb.firebaseio.com",
    projectId: "number-baseball-28392",
    storageBucket: "number-baseball-28392.firebasestorage.app",
    messagingSenderId: "613478280450",
    appId: "1:613478280450:web:211ebe0e64570f4e66e61b",
    measurementId: "G-K7Y19FJ5N7"
};

let app, database, auth;
// Promise that resolves once an authenticated user is available. RTDB security
// rules require auth != null, so any code that touches Firebase data MUST
// `await authReady` before issuing reads/writes. Default is a forever-pending
// promise so callers safely hang if Firebase init itself failed (rare). The
// real promise is assigned inside the try block below.
let authReady = new Promise(() => {});

try {
    app = firebase.initializeApp(firebaseConfig);
    database = firebase.database();
    auth = firebase.auth();

    // Anonymous sign-in: reuse cached session if the browser already has one,
    // otherwise mint a fresh anonymous account. Mirrors iOS YourApp.swift.
    // Pattern: wait for the first onAuthStateChanged. If it fires with a user,
    // a cached session was restored → resolve. If null, trigger signInAnonymously;
    // the next state-change callback will deliver the new user. `signInTriggered`
    // guards against double sign-in if multiple null callbacks arrive.
    authReady = new Promise((resolve, reject) => {
        let signInTriggered = false;
        const unsub = auth.onAuthStateChanged((user) => {
            if (user) {
                unsub();
                resolve(user);
                return;
            }
            if (!signInTriggered) {
                signInTriggered = true;
                auth.signInAnonymously().catch((err) => {
                    unsub();
                    console.error('Anonymous sign-in failed:', err);
                    reject(err);
                });
            }
        });
    });

    authReady.then((user) => {
        console.log('Auth ready, uid:', user.uid);
    }).catch(() => {});

    // Boot Analytics so events stream to the GA4 property linked to the
    // Firebase project (G-K7Y19FJ5N7 — same one iOS reports to).
    // firebase-analytics-compat.js auto-loads gtag.js under the hood.
    if (firebase.analytics) {
        firebase.analytics();
    }
    console.log('Firebase initialized.');
} catch (error) {
    console.error("Firebase init error:", error);
}

// Shared game state. Mutated by both solo.js and multiplayer.js.
let roomCode = '';
let playerId = 'player' + Date.now();
let isHost = false;
let answer = '';
let attempts = 0;
let gameEnded = false;
let gameMode = '';        // 'multiplayer' | 'solo'
let multiplayerMode = ''; // 'simultaneous' | 'turn-based'
let currentTurn = '';
let opponentId = '';
