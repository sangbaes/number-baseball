"""Worker pool management in botWorkers/ and lobby room cleanup.

WorkerPool: manages passive worker registration in botWorkers/.
LobbyCleanup: cleans up stale lobby rooms from previous bot runs.
"""

from __future__ import annotations

import logging

from firebase_admin import db

from .config import BotConfig

logger = logging.getLogger(__name__)


class WorkerPool:
    """Manages worker registration in botWorkers/."""

    def __init__(self, root: db.Reference, config: BotConfig) -> None:
        self._root = root
        self._config = config
        self._worker_ref = root.child(f"botWorkers/{config.worker_id}")

    def cleanup_stale_assignment(self) -> None:
        """On startup, clear any leftover assignment from a previous crash."""
        try:
            worker_data = self._worker_ref.get()
            if isinstance(worker_data, dict) and worker_data.get("assignment"):
                logger.info(
                    "Clearing stale assignment for worker %s (room=%s)",
                    self._config.worker_id,
                    worker_data["assignment"].get("roomCode", "?"),
                )
                self._worker_ref.update({
                    "status": "idle",
                    "assignment": None,
                    "updatedAt": {".sv": "timestamp"},
                })
        except Exception:
            logger.warning("Stale assignment cleanup failed", exc_info=True)

    def cleanup_stale_rooms(self) -> None:
        """Legacy compatibility — clean up any old publicRooms entries
        left over from the pre-refactor architecture."""
        group = self._config.group_code
        worker_id = self._config.worker_id

        try:
            public_rooms = self._root.child(f"publicRooms/{group}").get()
            if not public_rooms:
                return

            for room_code, room_info in public_rooms.items():
                if not isinstance(room_info, dict):
                    continue
                if worker_id and room_info.get("workerId") == worker_id:
                    logger.info("Cleaning up legacy stale room: %s (worker=%s)", room_code, worker_id)
                    self._root.child(f"publicRooms/{group}/{room_code}").delete()
                    # Also try to clean up the room itself if it exists
                    try:
                        room_data = self._root.child(f"rooms/{room_code}").get()
                        if isinstance(room_data, dict):
                            status = room_data.get("status", "")
                            players = room_data.get("players", {})
                            # Only delete if it's in lobby with no p2
                            if status == "lobby" and (not isinstance(players, dict) or "p2" not in players):
                                self._root.child(f"rooms/{room_code}").delete()
                                logger.info("Deleted legacy stale room: %s", room_code)
                    except Exception:
                        pass

        except Exception:
            logger.warning("Legacy stale room cleanup failed", exc_info=True)


class LobbyCleanup:
    """Cleans up stale lobby rooms from previous bot runs."""

    def __init__(self, root: db.Reference, config: BotConfig) -> None:
        self._root = root
        self._config = config

    def cleanup_stale_lobby_rooms(self) -> None:
        """Remove orphaned publicRooms/BOT entries and their rooms."""
        try:
            public = self._root.child("publicRooms/BOT").get()
            if not public or not isinstance(public, dict):
                return

            for room_code, info in public.items():
                if not isinstance(info, dict):
                    continue

                room_data = self._root.child(f"rooms/{room_code}").get()
                if not isinstance(room_data, dict):
                    # publicRooms entry exists but room doesn't — stale
                    self._root.child(f"publicRooms/BOT/{room_code}").delete()
                    logger.info("Removed orphan publicRooms/BOT entry: %s", room_code)
                    continue

                # Check if bot (p1) is still connected
                p1 = room_data.get("players", {}).get("p1", {})
                if isinstance(p1, dict) and not p1.get("connected", False):
                    # Bot crashed — clean up both room and public entry
                    self._root.update({
                        f"rooms/{room_code}": None,
                        f"publicRooms/BOT/{room_code}": None,
                    })
                    logger.info("Cleaned up crashed bot room: %s", room_code)
                elif room_data.get("status") == "lobby" and "p2" not in room_data.get("players", {}):
                    # Lobby room with no p2 from a previous run — clean up
                    self._root.update({
                        f"rooms/{room_code}": None,
                        f"publicRooms/BOT/{room_code}": None,
                    })
                    logger.info("Cleaned up stale lobby room: %s", room_code)

        except Exception:
            logger.warning("Lobby room cleanup failed", exc_info=True)
