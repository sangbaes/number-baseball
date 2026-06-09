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

let app, database;
try {
    app = firebase.initializeApp(firebaseConfig);
    database = firebase.database();
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
