"""Simple terminal console to monitor active lobby bots.

Usage: python -m worker.console [config.yaml] [--refresh N]
"""

from __future__ import annotations

import argparse
import logging
import sys
import time

from firebase_admin import db

from .config import Config
from .firebase_client import init_firebase

logger = logging.getLogger(__name__)


def build_display(root: db.Reference) -> str:
    """Build a text table showing bot room status."""
    lines: list[str] = []
    lines.append("")
    lines.append("=" * 72)
    lines.append("  Number Baseball Bot Console")
    lines.append("=" * 72)

    header = f"{'Room':<8} {'Bot Name':<20} {'Lv':>2} {'Status':<10} {'Round':>5} {'Players':<8} {'Winner':<8}"
    lines.append(header)
    lines.append("-" * 72)

    rows: list[dict] = []

    # 1. Lobby rooms from publicRooms/BOT
    try:
        public = root.child("publicRooms/BOT").get() or {}
    except Exception:
        public = {}

    lobby_codes: set[str] = set()
    for code, info in public.items():
        if not isinstance(info, dict):
            continue
        lobby_codes.add(code)
        rows.append({
            "code": code,
            "name": info.get("hostName", "?"),
            "level": info.get("level", "?"),
            "status": "LOBBY",
            "round": "-",
            "players": "1/2",
            "winner": "-",
        })

    # 2. Check individual rooms by code for playing/finished bot games
    #    We look up room codes from the tracked set (lobby rooms we already know)
    #    plus any rooms that have isBotRoom set (checked individually, no index needed)
    #    For now, scan publicRooms/BOT for known bot rooms and also check
    #    rooms that are currently being played (not in publicRooms anymore).
    try:
        # Read all rooms shallowly to find bot rooms
        all_rooms = root.child("rooms").get(shallow=True) or {}
    except Exception:
        all_rooms = {}

    for code in all_rooms:
        if code in lobby_codes:
            continue
        try:
            data = root.child(f"rooms/{code}").get()
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        if not data.get("isBotRoom"):
            continue

        status = data.get("status", "?")
        players = data.get("players", {})
        p1 = players.get("p1", {}) if isinstance(players, dict) else {}
        player_count = sum(1 for k in (players if isinstance(players, dict) else {}) if k in ("p1", "p2"))

        rounds = data.get("rounds", {})
        round_count = 0
        if isinstance(rounds, dict) and rounds:
            try:
                round_count = max(int(k) for k in rounds.keys())
            except (ValueError, TypeError):
                pass
        elif isinstance(rounds, list):
            round_count = sum(1 for r in rounds if r is not None)

        outcome = data.get("outcome", {})
        winner = outcome.get("winnerId", "-") if isinstance(outcome, dict) else "-"

        rows.append({
            "code": code,
            "name": p1.get("name", "?") if isinstance(p1, dict) else "?",
            "level": data.get("level", "?"),
            "status": status.upper(),
            "round": str(round_count),
            "players": f"{player_count}/2",
            "winner": winner,
        })

    if not rows:
        lines.append("  (no bot rooms found)")
    else:
        rows.sort(key=lambda r: (r["status"] != "LOBBY", r["status"] != "PLAYING", str(r["level"])))
        for r in rows:
            line = f"{r['code']:<8} {r['name']:<20} {str(r['level']):>2} {r['status']:<10} {r['round']:>5} {r['players']:<8} {r['winner']:<8}"
            lines.append(line)

    lines.append("-" * 72)
    lines.append(f"  Total: {len(rows)} room(s)")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Monitor Number Baseball bots")
    parser.add_argument("config", nargs="?", help="Path to YAML config file")
    parser.add_argument("--refresh", type=int, default=5, help="Refresh interval in seconds")
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)

    config = Config.load(args.config)
    root = init_firebase(config.firebase.service_account, config.firebase.database_url)

    print("Number Baseball Bot Console (Ctrl+C to exit)")
    print(f"Refreshing every {args.refresh}s...")

    try:
        while True:
            # Clear screen
            print("\033[2J\033[H", end="")
            print(build_display(root))
            time.sleep(args.refresh)
    except KeyboardInterrupt:
        print("\nConsole stopped.")
        sys.exit(0)


if __name__ == "__main__":
    main()
