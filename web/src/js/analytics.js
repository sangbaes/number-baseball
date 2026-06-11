// Web-side mirror of iOS AnalyticsService.swift.
// Same event names + parameter shapes so iOS and Web data unify in the
// Firebase-linked GA4 property (G-K7Y19FJ5N7). Initialized in firebase-config.js
// via firebase.analytics(); all logging goes through firebase.analytics().logEvent().

const GameAnalytics = (() => {
    function log(name, params) {
        try {
            if (typeof firebase === 'undefined' || !firebase.analytics) return;
            firebase.analytics().logEvent(name, params || {});
        } catch (e) {
            console.warn('[analytics] logEvent failed:', name, e);
        }
    }

    return {
        // Screen views — use Firebase reserved event name `screen_view` with
        // `screen_name` param so GA4 treats them like native screen views.
        screenView(name) {
            log('screen_view', { screen_name: name });
        },

        languageChanged(lang) {
            log('language_changed', { language: lang });
        },

        gameModeSelected(mode) {
            log('game_mode_selected', { mode: mode });
        },

        roomCreated(mode, isPublic) {
            log('room_created', {
                game_mode: mode,
                is_public: isPublic ? 'true' : 'false',
            });
        },

        roomJoined(method) {
            log('room_joined', { method: method });
        },

        roomLeft() {
            log('room_left', {});
        },

        guessSubmitted(attempt) {
            log('guess_submitted', { attempt_number: attempt });
        },

        gameWon(mode, attempts) {
            log('game_won', { mode: mode, attempts: attempts });
        },

        gameLost(mode, attempts) {
            log('game_lost', { mode: mode, attempts: attempts });
        },

        gameDraw(attempts) {
            log('game_draw', { attempts: attempts });
        },

        soloGameStarted() {
            log('solo_game_started', {});
        },

        soloGameWon(attempts) {
            log('solo_game_won', { attempts: attempts });
        },

        soloGameLost() {
            log('solo_game_lost', {});
        },

        howToPlayOpened() {
            log('how_to_play_opened', {});
        },
    };
})();
