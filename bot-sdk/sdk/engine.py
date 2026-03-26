"""Lobby engine: bot creates its own public room and waits for players.

States: IDLE -> LOBBY -> PLAYING -> FINISHED -> (loop)

FAIRNESS NOTE:
  strategy.next_guess(history) only receives (guess, strike, ball) feedback.
  It never has access to turnSecret. The local strike_ball() computation
  is the same self-judging mechanism that iOS players use.
"""

from __future__ import annotations

import logging
import queue
import random
import time
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum, auto

from firebase_admin import db

from .baseball import gen_room_code, random_secret, strike_ball
from .config import BotConfig
from .presence import PresenceManager
from .recorder import GameRecord, GameRecorder
from .strategy import Strategy, GuessResult

logger = logging.getLogger(__name__)

_REMATCH_WAIT_SECONDS = 30


class LobbyState(Enum):
    IDLE = auto()
    LOBBY = auto()
    PLAYING = auto()
    FINISHED = auto()


@dataclass
class GameResult:
    winner: str = ""
    reason: str = ""
    room_code: str = ""
    player_name: str = ""
    player_uid: str = ""
    rounds_played: int = 0


class LobbyEngine:
    """Bot player that creates its own room and waits for opponents."""

    def __init__(
        self,
        config: BotConfig,
        strategy: Strategy,
        root: db.Reference,
    ) -> None:
        self._config = config
        self._strategy = strategy
        self._root = root

        self._state = LobbyState.IDLE
        self._room_code: str = ""
        self._turn_secret: str = ""
        self._history: list[GuessResult] = []
        self._round_counter: int = 0

        self._room_listener: db.ListenerRegistration | None = None
        self._presence: PresenceManager | None = None
        self._room_queue: queue.Queue[db.Event] = queue.Queue()
        self._room_data: dict = {}

        self._shutdown_event = threading.Event()
        self._game_result: GameResult = GameResult()
        self._games_played: int = 0
        self._recorder: GameRecorder | None = (
            GameRecorder(config.record_dir) if config.record_dir else None
        )

    # -- Public API --

    def run(self) -> None:
        """Main loop. Runs until shutdown() is called."""
        logger.info("LobbyEngine starting (strategy=%s, name=%s, level=%d)",
                     self._strategy.name, self._config.name, self._config.level)

        while not self._shutdown_event.is_set():
            try:
                if self._state == LobbyState.IDLE:
                    self._do_idle()
                elif self._state == LobbyState.LOBBY:
                    self._do_lobby()
                elif self._state == LobbyState.PLAYING:
                    self._do_playing()
                elif self._state == LobbyState.FINISHED:
                    self._do_finished()
            except Exception:
                logger.error("Error in state %s", self._state.name, exc_info=True)
                self._safe_cleanup()
                self._state = LobbyState.IDLE
                time.sleep(self._config.restart_delay_seconds)

    def shutdown(self) -> None:
        """Signal the engine to shut down gracefully."""
        logger.info("Shutdown requested")
        self._shutdown_event.set()
        self._safe_cleanup()
        if self._room_code:
            try:
                group = self._config.group_code
                self._root.update({
                    f"rooms/{self._room_code}": None,
                    f"publicRooms/{group}/{self._room_code}": None,
                })
            except Exception:
                logger.warning("Failed to clean up room on shutdown", exc_info=True)

    @property
    def status_info(self) -> dict:
        return {
            "state": self._state.name,
            "room_code": self._room_code,
            "games_played": self._games_played,
            "round": self._round_counter,
            "name": self._config.name,
            "level": self._config.level,
            "strategy": self._strategy.name,
        }

    # -- State handlers --

    def _do_idle(self) -> None:
        self._history = []
        self._round_counter = 0
        self._room_data = {}
        self._turn_secret = ""
        self._strategy.reset()
        self._game_result = GameResult()

        while not self._room_queue.empty():
            try:
                self._room_queue.get_nowait()
            except queue.Empty:
                break

        self._room_code = gen_room_code()
        group = self._config.group_code

        self._root.update({
            f"rooms/{self._room_code}/status": "lobby",
            f"rooms/{self._room_code}/createdAt": {".sv": "timestamp"},
            f"rooms/{self._room_code}/hostId": "p1",
            f"rooms/{self._room_code}/gameMode": "turn",
            f"rooms/{self._room_code}/isPublic": True,
            f"rooms/{self._room_code}/isBotRoom": True,
            f"rooms/{self._room_code}/groupCode": group,
            f"rooms/{self._room_code}/currentTurn": "p1",
            f"rooms/{self._room_code}/players/p1/name": self._config.name,
            f"rooms/{self._room_code}/players/p1/joinedAt": {".sv": "timestamp"},
            f"rooms/{self._room_code}/players/p1/connected": True,
            f"publicRooms/{group}/{self._room_code}/hostName": self._config.name,
            f"publicRooms/{group}/{self._room_code}/gameMode": "turn",
            f"publicRooms/{group}/{self._room_code}/level": self._config.level,
            f"publicRooms/{group}/{self._room_code}/createdAt": {".sv": "timestamp"},
            f"publicRooms/{group}/{self._room_code}/playerCount": 1,
        })

        room_ref = self._root.child(f"rooms/{self._room_code}")
        self._room_listener = room_ref.listen(self._on_room_event)

        player_ref = self._root.child(f"rooms/{self._room_code}/players/p1")
        self._presence = PresenceManager(player_ref, self._config.heartbeat_interval)
        self._presence.start()

        self._state = LobbyState.LOBBY
        logger.info("-> LOBBY (room=%s, level=%d, name=%s)",
                     self._room_code, self._config.level, self._config.name)

    def _do_lobby(self) -> None:
        self._drain_and_sync()
        if self._check_lobby_transitions():
            return

        try:
            event = self._room_queue.get(timeout=30.0)
        except queue.Empty:
            return

        self._apply_event(event)
        while True:
            try:
                event = self._room_queue.get_nowait()
                self._apply_event(event)
            except queue.Empty:
                break

        self._check_lobby_transitions()

    def _check_lobby_transitions(self) -> bool:
        if not self._room_data:
            logger.info("Room deleted externally while in lobby")
            self._safe_cleanup()
            self._state = LobbyState.IDLE
            return True

        status = self._room_data.get("status", "lobby")
        if status == "playing":
            turn_secret = self._room_data.get("turnSecret")
            if turn_secret:
                self._turn_secret = turn_secret
                logger.info("-> PLAYING (game started by opponent, room=%s)", self._room_code)
                self._state = LobbyState.PLAYING
                return True

        players = self._room_data.get("players", {})
        if isinstance(players, dict) and "p2" in players:
            p2 = players["p2"]
            p2_name = p2.get("name", "?") if isinstance(p2, dict) else "?"
            logger.info("Player joined: %s", p2_name)
            self._start_game()
            self._state = LobbyState.PLAYING
            return True

        return False

    def _do_playing(self) -> None:
        try:
            event = self._room_queue.get(timeout=30.0)
        except queue.Empty:
            return

        self._apply_event(event)
        while True:
            try:
                event = self._room_queue.get_nowait()
                self._apply_event(event)
            except queue.Empty:
                break

        if not self._room_data:
            logger.info("Room deleted - ending game")
            self._state = LobbyState.FINISHED
            return

        if not self._turn_secret:
            turn_secret = self._room_data.get("turnSecret")
            status = self._room_data.get("status")
            if status == "playing" and turn_secret:
                self._turn_secret = turn_secret
                logger.info("Game started (turnSecret received)")
                time.sleep(0.3)
                self._drain_and_sync()
            return

        if self._room_data.get("outcome"):
            outcome = self._room_data.get("outcome", {})
            logger.info("Game outcome detected: type=%s, winner=%s",
                        outcome.get("type", "?"), outcome.get("winnerId", "?"))
            self._state = LobbyState.FINISHED
            return

        if self._check_p2_solved():
            return

        players = self._room_data.get("players", {})
        if isinstance(players, dict):
            p2 = players.get("p2")
            p2_gone = p2 is None
            p2_disconnected = isinstance(p2, dict) and p2.get("connected") is False

            if p2_gone or p2_disconnected:
                self._drain_and_sync()
                players = self._room_data.get("players", {})
                p2 = players.get("p2") if isinstance(players, dict) else None
                p2_gone = p2 is None
                p2_disconnected = isinstance(p2, dict) and p2.get("connected") is False

                if p2_gone or p2_disconnected:
                    logger.info("Opponent disconnected - forfeit")
                    self._decide_outcome("forfeit", "p1", "disconnect")
                    self._state = LobbyState.FINISHED
                    return

        self._drain_and_sync()
        current_turn = self._room_data.get("currentTurn")

        if current_turn != "p1":
            return

        rounds = self._room_data.get("rounds", {})
        expected_round = str(self._round_counter + 1)
        if isinstance(rounds, dict):
            existing = rounds.get(expected_round, {})
            if isinstance(existing, dict):
                p1_guess = existing.get("guessFrom", {})
                if isinstance(p1_guess, dict) and p1_guess.get("p1"):
                    return

        self._submit_guess()

    def _do_finished(self) -> None:
        self._drain_and_sync()
        self._collect_game_result()
        self._record_game()
        self._games_played += 1

        outcome = self._room_data.get("outcome", {})
        winner = outcome.get("winnerId", "?") if isinstance(outcome, dict) else "?"
        logger.info("Game #%d finished: winner=%s, rounds=%d",
                     self._games_played, winner, self._round_counter)

        room_ref = self._root.child(f"rooms/{self._room_code}")
        room_ref.child("rematch/p1").set(True)
        logger.info("Waiting for rematch request (%.0fs timeout)...",
                     _REMATCH_WAIT_SECONDS)

        rematch_accepted = self._wait_for_rematch()
        group = self._config.group_code

        if rematch_accepted:
            old_code = self._room_code
            new_code = gen_room_code()
            logger.info("Rematch accepted! Creating new room %s", new_code)

            # 1. Create new room FIRST (must exist before opponent tries to join)
            self._root.update({
                f"rooms/{new_code}/status": "lobby",
                f"rooms/{new_code}/createdAt": {".sv": "timestamp"},
                f"rooms/{new_code}/hostId": "p1",
                f"rooms/{new_code}/gameMode": "turn",
                f"rooms/{new_code}/isPublic": False,
                f"rooms/{new_code}/isBotRoom": True,
                f"rooms/{new_code}/groupCode": group,
                f"rooms/{new_code}/currentTurn": "p1",
                f"rooms/{new_code}/players/p1/name": self._config.name,
                f"rooms/{new_code}/players/p1/joinedAt": {".sv": "timestamp"},
                f"rooms/{new_code}/players/p1/connected": True,
            })

            # 2. Tell opponent where to go (room already exists)
            room_ref.child("rematch/newRoomCode").set(new_code)

            # 3. Switch to new room
            self._safe_cleanup()
            self._history = []
            self._round_counter = 0
            self._room_data = {}
            self._turn_secret = ""
            self._strategy.reset()
            self._game_result = GameResult()
            while not self._room_queue.empty():
                try:
                    self._room_queue.get_nowait()
                except queue.Empty:
                    break

            self._room_code = new_code
            self._room_listener = self._root.child(
                f"rooms/{new_code}"
            ).listen(self._on_room_event)
            player_ref = self._root.child(f"rooms/{new_code}/players/p1")
            self._presence = PresenceManager(player_ref, self._config.heartbeat_interval)
            self._presence.start()

            logger.info("-> LOBBY (rematch room=%s)", new_code)
            self._state = LobbyState.LOBBY

            # 4. Delete old room after delay
            time.sleep(5)
            try:
                self._root.update({
                    f"rooms/{old_code}": None,
                    f"publicRooms/{group}/{old_code}": None,
                })
            except Exception:
                logger.warning("Failed to delete old room %s", old_code, exc_info=True)
        else:
            logger.info("No rematch. Cleaning up...")
            try:
                self._root.update({
                    f"rooms/{self._room_code}": None,
                    f"publicRooms/{group}/{self._room_code}": None,
                })
            except Exception:
                logger.warning("Failed to delete room %s", self._room_code, exc_info=True)

            self._safe_cleanup()

            if not self._shutdown_event.is_set():
                logger.info("Restarting in %ds...", self._config.restart_delay_seconds)
                time.sleep(self._config.restart_delay_seconds)
                self._state = LobbyState.IDLE

    def _wait_for_rematch(self) -> bool:
        deadline = time.monotonic() + _REMATCH_WAIT_SECONDS
        while time.monotonic() < deadline:
            if self._shutdown_event.is_set():
                return False
            self._drain_and_sync()
            rematch = self._room_data.get("rematch", {})
            if isinstance(rematch, dict) and rematch.get("p2") is True:
                return True
            players = self._room_data.get("players", {})
            p2 = players.get("p2") if isinstance(players, dict) else None
            if p2 is None:
                logger.info("p2 left - skipping rematch wait")
                return False
            if isinstance(p2, dict) and p2.get("connected") is False:
                logger.info("p2 disconnected - skipping rematch wait")
                return False
            time.sleep(2)
        return False

    # -- Game actions --

    def _start_game(self) -> None:
        self._drain_and_sync()
        if self._room_data.get("status") == "playing":
            self._turn_secret = self._room_data.get("turnSecret", "")
            logger.info("Game already started by opponent (race condition handled)")
            return

        self._turn_secret = random_secret()
        group = self._config.group_code
        room_ref = self._root.child(f"rooms/{self._room_code}")
        room_ref.update({
            "status": "playing",
            "currentTurn": "p1",
            "turnSecret": self._turn_secret,
        })

        self._root.child(f"publicRooms/{group}/{self._room_code}").delete()
        logger.info("-> PLAYING (game started, room=%s)", self._room_code)

        time.sleep(0.3)
        self._drain_and_sync()
        actual_secret = self._room_data.get("turnSecret", self._turn_secret)
        if actual_secret != self._turn_secret:
            logger.warning("turnSecret mismatch (race), using Firebase value")
            self._turn_secret = actual_secret

    def _submit_guess(self) -> None:
        delay = self._config.guess_delay_seconds + random.uniform(0, 1.0)
        time.sleep(delay)

        self._drain_and_sync()
        if self._room_data.get("currentTurn") != "p1":
            return
        if self._room_data.get("outcome"):
            return

        opponent_history = self._collect_opponent_history()
        combined = self._history + opponent_history
        guess = self._strategy.next_guess(combined)
        s, b = strike_ball(self._turn_secret, guess)
        self._history.append(GuessResult(guess, s, b))
        self._round_counter += 1

        next_round = self._round_counter
        room_ref = self._root.child(f"rooms/{self._room_code}")

        updates: dict = {
            f"rounds/{next_round}/guessFrom/p1/value": guess,
            f"rounds/{next_round}/guessFrom/p1/ts": {".sv": "timestamp"},
            f"rounds/{next_round}/resultFor/p1/strike": s,
            f"rounds/{next_round}/resultFor/p1/ball": b,
            f"rounds/{next_round}/resultFor/p1/ts": {".sv": "timestamp"},
            "currentTurn": "p2",
        }

        if s == 3:
            updates["solvedAt/p1"] = {".sv": "timestamp"}
            updates["outcome/type"] = "win"
            updates["outcome/winnerId"] = "p1"
            updates["outcome/reason"] = "solved"
            updates["outcome/decidedAt"] = {".sv": "timestamp"}
            updates["status"] = "finished"

        room_ref.update(updates)
        logger.info("Guess #%d: %s -> %dS %dB", self._round_counter, guess, s, b)

        if s == 3:
            logger.info("Bot solved! Game over.")
            self._state = LobbyState.FINISHED

    def _collect_opponent_history(self) -> list[GuessResult]:
        """Extract opponent's guess history from room_data rounds."""
        raw_rounds = self._room_data.get("rounds", {})

        # Handle Firebase NSArray conversion (sequential keys -> list)
        if isinstance(raw_rounds, list):
            converted = {}
            for i, v in enumerate(raw_rounds):
                if v is not None:
                    converted[str(i)] = v
            raw_rounds = converted

        if not isinstance(raw_rounds, dict):
            return []

        result = []
        for round_key in sorted(raw_rounds.keys(), key=lambda k: int(k)):
            rd = raw_rounds[round_key]
            if not isinstance(rd, dict):
                continue

            guess_from = rd.get("guessFrom", {}) or {}
            result_for = rd.get("resultFor", {}) or {}
            p2_guess = guess_from.get("p2", {}) or {}
            p2_result = result_for.get("p2", {}) or {}

            value = p2_guess.get("value")
            strike = p2_result.get("strike")
            ball = p2_result.get("ball")

            if value is not None and strike is not None and ball is not None:
                result.append(GuessResult(value, strike, ball))

        return result

    def _check_p2_solved(self) -> bool:
        solved_at = self._room_data.get("solvedAt", {})
        if isinstance(solved_at, dict) and solved_at.get("p2"):
            logger.info("Opponent solved the secret!")
            self._decide_outcome("win", "p2", "solved")
            self._state = LobbyState.FINISHED
            return True
        return False

    def _decide_outcome(self, outcome_type: str, winner_id: str, reason: str) -> None:
        room_ref = self._root.child(f"rooms/{self._room_code}")
        room_ref.update({
            "outcome/type": outcome_type,
            "outcome/winnerId": winner_id,
            "outcome/reason": reason,
            "outcome/decidedAt": {".sv": "timestamp"},
            "status": "finished",
        })
        logger.info("Outcome: %s, winner=%s, reason=%s", outcome_type, winner_id, reason)

    def _collect_game_result(self) -> None:
        outcome = self._room_data.get("outcome", {})
        if isinstance(outcome, dict):
            self._game_result.winner = outcome.get("winnerId", "")
            self._game_result.reason = outcome.get("reason", "")
        self._game_result.room_code = self._room_code
        self._game_result.rounds_played = self._round_counter

        players = self._room_data.get("players", {})
        p2 = players.get("p2", {})
        if isinstance(p2, dict):
            self._game_result.player_name = p2.get("name", "")
            self._game_result.player_uid = p2.get("uid", "")

    def _record_game(self) -> None:
        """Record the completed game to JSONL for LLM training."""
        if not self._recorder:
            return

        try:
            rounds = GameRecorder.extract_rounds(self._room_data)

            players = self._room_data.get("players", {})
            p2 = players.get("p2", {}) if isinstance(players, dict) else {}
            opponent_name = p2.get("name", "") if isinstance(p2, dict) else ""
            opponent_uid = p2.get("uid", "") if isinstance(p2, dict) else ""

            outcome = self._room_data.get("outcome", {})
            winner = outcome.get("winnerId", "") if isinstance(outcome, dict) else ""
            reason = outcome.get("reason", "") if isinstance(outcome, dict) else ""

            record = GameRecord(
                timestamp=datetime.now(timezone.utc).isoformat(),
                room_code=self._room_code,
                bot_name=self._config.name,
                bot_strategy=self._strategy.name,
                opponent_name=opponent_name,
                opponent_uid=opponent_uid,
                level=self._config.level,
                secret=self._turn_secret,
                rounds=rounds,
                winner=winner,
                reason=reason,
                total_rounds=self._round_counter,
            )

            self._recorder.record(record)
        except Exception:
            logger.warning("Failed to record game", exc_info=True)

    # -- Event handling --

    def _on_room_event(self, event: db.Event) -> None:
        self._room_queue.put(event)

    def _drain_and_sync(self) -> None:
        while True:
            try:
                self._room_queue.get_nowait()
            except queue.Empty:
                break
        try:
            fresh = self._root.child(f"rooms/{self._room_code}").get()
            if isinstance(fresh, dict):
                self._room_data = fresh
            elif fresh is None:
                self._room_data = {}
        except Exception:
            logger.warning("Failed to re-sync room data", exc_info=True)

    def _apply_event(self, event: db.Event) -> None:
        if event.path == "/":
            if isinstance(event.data, dict):
                self._room_data = event.data
            elif event.data is None:
                self._room_data = {}
        else:
            path_parts = [p for p in event.path.split("/") if p]
            self._set_nested(self._room_data, path_parts, event.data)

        rounds = self._room_data.get("rounds", {})
        if isinstance(rounds, dict) and rounds:
            try:
                self._round_counter = max(int(k) for k in rounds.keys())
            except (ValueError, TypeError):
                pass

    @staticmethod
    def _set_nested(data: dict, path: list[str], value) -> None:
        current = data
        for key in path[:-1]:
            if key not in current or not isinstance(current[key], dict):
                current[key] = {}
            current = current[key]
        if path:
            if value is None:
                current.pop(path[-1], None)
            else:
                current[path[-1]] = value

    # -- Cleanup --

    def _safe_cleanup(self) -> None:
        if self._room_listener:
            try:
                self._room_listener.close()
            except Exception:
                pass
            self._room_listener = None

        if self._presence:
            self._presence.stop()
            self._presence = None

        self._room_code = ""
