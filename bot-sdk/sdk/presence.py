"""Heartbeat-based presence management.

Python firebase-admin SDK does not support onDisconnect(),
so we use a periodic heartbeat to prove the bot is alive.
"""

from __future__ import annotations

import logging
import threading

from firebase_admin import db

logger = logging.getLogger(__name__)


class PresenceManager:
    """Periodically writes connected=True to prove the bot is alive."""

    def __init__(self, player_ref: db.Reference, interval: int = 15) -> None:
        self._player_ref = player_ref
        self._interval = interval
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        try:
            self._player_ref.child("connected").set(False)
        except Exception:
            logger.warning("Failed to set disconnected state", exc_info=True)

    def _heartbeat_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                self._player_ref.update({
                    "connected": True,
                    "lastSeen": {".sv": "timestamp"},
                })
            except Exception:
                logger.warning("Heartbeat write failed", exc_info=True)
            self._stop_event.wait(self._interval)
