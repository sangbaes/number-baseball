"""Cleanup stale bot rooms from previous runs."""

from __future__ import annotations

import logging

from firebase_admin import db

logger = logging.getLogger(__name__)


class LobbyCleanup:
    """Cleans up stale lobby rooms from previous bot runs."""

    def __init__(self, root: db.Reference, group_code: str) -> None:
        self._root = root
        self._group_code = group_code

    def run(self) -> None:
        """Remove orphaned publicRooms entries and their rooms."""
        try:
            public = self._root.child(f"publicRooms/{self._group_code}").get()
            if not public or not isinstance(public, dict):
                return

            for room_code, info in public.items():
                if not isinstance(info, dict):
                    continue

                room_data = self._root.child(f"rooms/{room_code}").get()
                if not isinstance(room_data, dict):
                    self._root.child(f"publicRooms/{self._group_code}/{room_code}").delete()
                    logger.info("Removed orphan publicRooms entry: %s", room_code)
                    continue

                p1 = room_data.get("players", {}).get("p1", {})
                if isinstance(p1, dict) and not p1.get("connected", False):
                    self._root.update({
                        f"rooms/{room_code}": None,
                        f"publicRooms/{self._group_code}/{room_code}": None,
                    })
                    logger.info("Cleaned up crashed bot room: %s", room_code)
                elif room_data.get("status") == "lobby" and "p2" not in room_data.get("players", {}):
                    self._root.update({
                        f"rooms/{room_code}": None,
                        f"publicRooms/{self._group_code}/{room_code}": None,
                    })
                    logger.info("Cleaned up stale lobby room: %s", room_code)

        except Exception:
            logger.warning("Lobby room cleanup failed", exc_info=True)
