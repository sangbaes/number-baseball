from __future__ import annotations

import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, db


def init_firebase(service_account_path: str, database_url: str) -> db.Reference:
    """Initialize Firebase Admin SDK and return the root database reference."""

    # Resolve relative path from worker/ directory
    if not os.path.isabs(service_account_path):
        service_account_path = str(Path(__file__).parent / service_account_path)

    if not os.path.exists(service_account_path):
        raise FileNotFoundError(
            f"Service account key not found: {service_account_path}\n"
            "Download from: Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key"
        )

    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred, {"databaseURL": database_url})

    return db.reference()
