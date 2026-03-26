"""Game engine: bot as a pure player (p1) in a turn-based room.

Architecture (방식 A — 단순화):
- Worker registers itself at botWorkers/{workerId} with status="idle"
- iOS finds idle worker, creates room, writes assignment to botWorkers
- Worker detects assignment → listens rooms/{code} → plays the game
- Worker never creates or cleans up rooms (iOS handles all lifecycle)
- Worker never touches publicRooms

States: IDLE → WAITING → PLAYING → FINISHED → (reset) → IDLE
"""

from __future__ import annotations

import logging
import queue
import random
import time
import threading
from dataclasses import dataclass
from enum import Enum, auto

from firebase_admin import db

from .baseball import strike_ball
from .config import BotConfig
from .presence import PresenceManager
from .strategy import Strategy
from .strategy.base import GuessResult

logger = logging.getLogger(__name__)


class State(Enum):
    IDLE = auto()
    WAITING = auto()   # registered as idle, waiting for assignment from iOS
    PLAYING = auto()
    FINISHED = auto()


@dataclass
class GameResult:
    """Result of a single game."""
    winner: str = ""
    reason: str = ""
    room_code: str = ""
    player_uid: str = ""
    player_name: str = ""
    rounds_played: int = 0


class GameEngine:
    """Bot player — registers in botWorkers pool, waits for iOS assignment,
    listens to assigned room, submits guesses, observes outcome."""

    def __init__(
        self,
        config: BotConfig,
        strategy: Strategy,
        root: db.Reference,
    ) -> None:
        self._config = config
        self._strategy = strategy
        self._root = root

        self._state = State.IDLE
        self._room_code: str = ""
        self._turn_secret: str = ""
        self._history: list[GuessResult] = []
        self._round_counter: int = 0

        self._room_listener: db.ListenerRegistration | None = None
        self._assignment_listener: db.ListenerRegistration | None = None
        self._presence: PresenceManager | None = None
        self._assignment_queue: queue.Queue[db.Event] = queue.Queue()
        self._room_queue: queue.Queue[db.Event] = queue.Queue()
        self._room_data: dict = {}

        self._shutdown_event = threading.Event()
        self._game_result: GameResult = GameResult()

        self._worker_ref = self._root.child(f"botWorkers/{self._config.worker_id}")

    # ── Public API ──────────────────────────────────────────────

    def run(self) -> None:
        """Main loop. Runs until shutdown() is called."""
        logger.info("GameEngine starting (strategy=%s)", self._strategy.name)

        while not self._shutdown_event.is_set():
            try:
                if self._state == State.IDLE:
                    self._do_idle()
                elif self._state == State.WAITING:
                    self._do_waiting()
                elif self._state == State.PLAYING:
                    self._do_playing()
                elif self._state == State.FINISHED:
                    self._do_finished()
            except Exception:
                logger.error("Error in state %s", self._state.name, exc_info=True)
                self._safe_cleanup()
                self._state = State.IDLE
                time.sleep(self._config.restart_delay_seconds)

    def shutdown(self) -> None:
        """Signal the engine to shut down gracefully."""
        logger.info("Shutdown requested")
        self._shutdown_event.set()
        self._safe_cleanup()
        # Remove from botWorkers pool entirely on shutdown
        try:
            self._worker_ref.delete()
        except Exception:
            logger.warning("Failed to remove worker from pool", exc_info=True)

    # ── State handlers ──────────────────────────────────────────

    def _do_idle(self) -> None:
        """Register as idle in botWorkers pool and wait for assignment."""
        self._history = []
        self._round_counter = 0
        self._room_data = {}
        self._turn_secret = ""
        self._room_code = ""
        self._strategy.reset()

        # Register in botWorkers pool
        self._worker_ref.set({
            "status": "idle",
            "config": {
                "name": self._config.name,
                "level": self._config.level,
                "groupCode": self._config.group_code,
            },
            "updatedAt": {".sv": "timestamp"},
        })

        # Listen for assignment from iOS
        assignment_ref = self._worker_ref.child("assignment")
        self._assignment_listener = assignment_ref.listen(self._on_assignment_event)

        self._state = State.WAITING
        logger.info("→ WAITING (registered as idle, worker=%s)", self._config.worker_id)

    def _do_waiting(self) -> None:
        """Wait for iOS to assign a room via botWorkers/{workerId}/assignment."""
        try:
            event = self._assignment_queue.get(timeout=30.0)
        except queue.Empty:
            return  # timeout, keep waiting

        # Check if assignment arrived
        assignment = self._worker_ref.child("assignment").get()
        if not isinstance(assignment, dict):
            return

        room_code = assignment.get("roomCode")
        if not room_code:
            return

        self._room_code = room_code
        logger.info("Assignment received: room=%s", self._room_code)

        # Stop assignment listener (we got our assignment)
        if self._assignment_listener:
            try:
                self._assignment_listener.close()
            except Exception:
                pass
            self._assignment_listener = None

        # Drain any remaining assignment events
        while not self._assignment_queue.empty():
            try:
                self._assignment_queue.get_nowait()
            except queue.Empty:
                break

        # Update status to playing
        self._worker_ref.child("status").set("playing")

        # Start listening to the room
        room_ref = self._root.child(f"rooms/{self._room_code}")
        self._room_listener = room_ref.listen(self._on_room_event)

        # Start presence heartbeat on our player node
        player_ref = self._root.child(f"rooms/{self._room_code}/players/p1")
        self._presence = PresenceManager(player_ref, self._config.heartbeat_interval)
        self._presence.start()

        # Wait for game to start (status=playing + turnSecret)
        # Drain initial events and sync
        time.sleep(0.5)
        self._drain_and_sync()

        status = self._room_data.get("status")
        turn_secret = self._room_data.get("turnSecret")

        if status == "playing" and turn_secret:
            self._turn_secret = turn_secret
            self._state = State.PLAYING
            logger.info("→ PLAYING (game already started, room=%s)", self._room_code)
        else:
            # Game not started yet, transition to PLAYING state to wait for it
            self._state = State.PLAYING
            logger.info("→ PLAYING (waiting for game start, room=%s)", self._room_code)

    def _do_playing(self) -> None:
        """Handle the turn-based game loop. Only submit guesses on our turn.
        Outcome is decided by iOS — we just observe it."""
        try:
            event = self._room_queue.get(timeout=30.0)
        except queue.Empty:
            return

        # Apply all pending room events (not just the last one)
        self._apply_event(event)
        while True:
            try:
                event = self._room_queue.get_nowait()
                self._apply_event(event)
            except queue.Empty:
                break

        # Room was deleted (iOS left)
        if not self._room_data:
            logger.info("Room deleted — ending game")
            self._state = State.FINISHED
            return

        # If we don't have turnSecret yet, game hasn't started
        if not self._turn_secret:
            turn_secret = self._room_data.get("turnSecret")
            status = self._room_data.get("status")
            if status == "playing" and turn_secret:
                self._turn_secret = turn_secret
                logger.info("Game started (turnSecret received, room=%s)", self._room_code)
                time.sleep(0.3)
                self._drain_and_sync()
            return  # wait for next event

        # Check if game is over (outcome set by iOS)
        if self._room_data.get("outcome"):
            outcome = self._room_data.get("outcome", {})
            logger.info(
                "Game outcome detected: type=%s, winner=%s, reason=%s",
                outcome.get("type", "?"),
                outcome.get("winnerId", "?"),
                outcome.get("reason", "?"),
            )
            self._state = State.FINISHED
            return

        # Check if opponent disconnected (p2 removed from players)
        # Re-sync from Firebase to avoid acting on stale/partial local data
        players = self._room_data.get("players", {})
        if isinstance(players, dict) and "p2" not in players:
            self._drain_and_sync()
            players = self._room_data.get("players", {})
            if isinstance(players, dict) and "p2" not in players:
                logger.info("Opponent (p2) disconnected — ending game (confirmed via sync)")
                self._state = State.FINISHED
                return

        # Re-read currentTurn from Firebase to avoid stale local data
        self._drain_and_sync()
        current_turn = self._room_data.get("currentTurn")
        logger.debug(
            "Turn check: currentTurn=%s, round=%d",
            current_turn, self._round_counter,
        )

        if current_turn != "p1":
            return

        # Verify we haven't already submitted for this round
        rounds = self._room_data.get("rounds", {})
        expected_round = str(self._round_counter + 1)
        if isinstance(rounds, dict):
            existing = rounds.get(expected_round, {})
            if isinstance(existing, dict):
                p1_guess = existing.get("guessFrom", {})
                if isinstance(p1_guess, dict) and p1_guess.get("p1"):
                    logger.warning(
                        "Round %s already has p1 guess, skipping",
                        expected_round,
                    )
                    return

        self._submit_guess()

    def _do_finished(self) -> None:
        """Clean up listeners and return to idle. Room cleanup is iOS's job."""
        self._collect_game_result()
        outcome = self._room_data.get("outcome", {})
        logger.info(
            "Game finished: type=%s, winner=%s, reason=%s",
            outcome.get("type", "?"),
            outcome.get("winnerId", "?"),
            outcome.get("reason", "?"),
        )

        self._safe_cleanup()

        if not self._shutdown_event.is_set():
            logger.info("Restarting in %ds...", self._config.restart_delay_seconds)
            time.sleep(self._config.restart_delay_seconds)
            self._state = State.IDLE

    def _collect_game_result(self) -> None:
        """Extract game result from room data."""
        outcome = self._room_data.get("outcome", {})
        self._game_result.winner = outcome.get("winnerId", "")
        self._game_result.reason = outcome.get("reason", "")
        self._game_result.room_code = self._room_code
        self._game_result.rounds_played = self._round_counter

        players = self._room_data.get("players", {})
        p2 = players.get("p2", {})
        if isinstance(p2, dict):
            self._game_result.player_name = p2.get("name", "")
            self._game_result.player_uid = p2.get("uid", "")

    # ── Game actions ────────────────────────────────────────────

    def _submit_guess(self) -> None:
        """Compute and submit a guess. Read turnSecret from Firebase data."""
        delay = self._config.guess_delay_seconds + random.uniform(0, 1.0)
        time.sleep(delay)

        # Re-verify it's still our turn (may have changed during delay)
        self._drain_and_sync()
        current_turn = self._room_data.get("currentTurn")
        if current_turn != "p1":
            logger.info("Turn changed during delay (now=%s), skipping guess", current_turn)
            return

        # Check if outcome already decided
        if self._room_data.get("outcome"):
            logger.info("Outcome already set, skipping guess")
            return

        # Use turnSecret from Firebase (set by iOS)
        turn_secret = self._room_data.get("turnSecret", self._turn_secret)
        if not turn_secret:
            logger.warning("No turnSecret available, skipping guess")
            return

        guess = self._strategy.next_guess(self._history)
        s, b = strike_ball(turn_secret, guess)
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

        room_ref.update(updates)
        logger.info("Guess #%d: %s → %dS %dB", self._round_counter, guess, s, b)

        time.sleep(0.3)
        self._drain_and_sync()

        # If 3S, just log — iOS will set the outcome via maybeDecideOutcome
        if s == 3:
            logger.info("Bot solved the secret! Waiting for outcome from host...")

    # ── Event handling ──────────────────────────────────────────

    def _on_room_event(self, event: db.Event) -> None:
        """Callback from Firebase room listener (runs on background thread)."""
        self._room_queue.put(event)

    def _on_assignment_event(self, event: db.Event) -> None:
        """Callback from Firebase assignment listener (runs on background thread)."""
        self._assignment_queue.put(event)

    def _drain_and_sync(self) -> None:
        """Drain pending events and re-sync room_data from Firebase directly."""
        while True:
            try:
                self._room_queue.get_nowait()
            except queue.Empty:
                break
        try:
            fresh = self._root.child(f"rooms/{self._room_code}").get()
            if isinstance(fresh, dict):
                self._room_data = fresh
        except Exception:
            logger.warning("Failed to re-sync room data", exc_info=True)

    def _apply_event(self, event: db.Event) -> None:
        """Apply a Firebase event to the local room_data mirror."""
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
        """Set a value in a nested dict following a path."""
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

    # ── Cleanup ─────────────────────────────────────────────────

    def _safe_cleanup(self) -> None:
        """Clean up listeners and presence. Does NOT touch rooms (iOS's job)."""
        if self._room_listener:
            try:
                self._room_listener.close()
            except Exception:
                pass
            self._room_listener = None

        if self._assignment_listener:
            try:
                self._assignment_listener.close()
            except Exception:
                pass
            self._assignment_listener = None

        if self._presence:
            self._presence.stop()
            self._presence = None

        # Clear assignment and return to idle in botWorkers
        try:
            self._worker_ref.update({
                "status": "idle",
                "assignment": None,
                "updatedAt": {".sv": "timestamp"},
            })
        except Exception:
            logger.warning("Failed to reset worker status", exc_info=True)

        self._room_code = ""
