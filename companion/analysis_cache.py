"""
SQLite-backed analysis cache for the melodize-companion.

Tracks which songs have been analyzed and their results so batch
analysis is resumable and incremental.
"""

import json
import logging
import os
import sqlite3
import time
from typing import Optional

log = logging.getLogger("melodize-companion.cache")

SCHEMA_VERSION = 3

_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS analysis_cache (
    song_id     TEXT PRIMARY KEY,
    file_path   TEXT NOT NULL,
    file_mtime  REAL NOT NULL,
    file_size   INTEGER NOT NULL,
    bpm         REAL,
    camelot_key TEXT,
    energy      REAL,
    spectral_centroid REAL,
    duration    REAL,
    tail_silence REAL DEFAULT 0,
    data_version INTEGER DEFAULT 1,
    phrase_positions TEXT,
    analyzed_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_analysis_file_path ON analysis_cache(file_path);
"""


class AnalysisCache:
    """Thread-safe (via check_same_thread=False + per-operation connections)."""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self._ensure_db()

    def _conn(self):
        return sqlite3.connect(self.db_path, check_same_thread=False)

    def _ensure_db(self):
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = self._conn()
        try:
            conn.executescript(_CREATE_SQL)
            # Migration: add tail_silence column for schema v1→v2.
            try:
                conn.execute("ALTER TABLE analysis_cache ADD COLUMN tail_silence REAL DEFAULT 0")
            except sqlite3.OperationalError:
                pass  # column already exists
            conn.commit()
        finally:
            conn.close()

    def get(self, song_id: str) -> Optional[dict]:
        """Return cached analysis for a song, or None."""
        conn = self._conn()
        try:
            cur = conn.execute(
                "SELECT * FROM analysis_cache WHERE song_id = ?", (song_id,)
            )
            row = cur.fetchone()
            if row is None:
                return None
            return {
                "song_id": row[0],
                "file_path": row[1],
                "file_mtime": row[2],
                "file_size": row[3],
                "bpm": row[4],
                "key": row[5],
                "energy": row[6],
                "spectral_centroid": row[7],
                "duration": row[8],
                "tail_silence": row[9] if row[9] is not None else 0.0,
                "data_version": row[10],
                "analyzed_at": row[11],
            }
        finally:
            conn.close()

    def needs_update(self, file_path: str, mtime: float, size: int) -> bool:
        """Check if a file needs (re-)analysis based on mtime/size."""
        conn = self._conn()
        try:
            cur = conn.execute(
                "SELECT file_mtime, file_size, data_version FROM analysis_cache "
                "WHERE file_path = ?",
                (file_path,),
            )
            row = cur.fetchone()
            if row is None:
                return True
            old_mtime, old_size, version = row
            if version < SCHEMA_VERSION:
                return True
            return old_mtime != mtime or old_size != size
        finally:
            conn.close()

    def set(self, song_id: str, file_path: str, mtime: float, size: int,
            analysis: dict) -> None:
        """Store or update analysis results."""
        conn = self._conn()
        phrase_json = json.dumps(analysis.get("phrase_positions")) \
            if analysis.get("phrase_positions") else None
        try:
            conn.execute(
                """INSERT OR REPLACE INTO analysis_cache
                   (song_id, file_path, file_mtime, file_size,
                    bpm, camelot_key, energy, spectral_centroid, duration,
                    tail_silence, data_version, analyzed_at, phrase_positions)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?)""",
                (
                    song_id,
                    file_path,
                    mtime,
                    size,
                    analysis.get("bpm"),
                    analysis.get("key"),
                    analysis.get("energy"),
                    analysis.get("spectral_centroid"),
                    analysis.get("duration"),
                    analysis.get("tail_silence", 0.0),
                    SCHEMA_VERSION,
                    phrase_json,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def get_all_stale(self, songs: list[dict]) -> list[dict]:
        """
        Given a list of {song_id, file_path, mtime, size}, return only
        the ones that need (re-)analysis.
        """
        stale = []
        for s in songs:
            if self.needs_update(s["file_path"], s["mtime"], s["size"]):
                stale.append(s)
        return stale

    def get_all_results(self) -> list[dict]:
        """Return all cached results (for initial sync to Flutter)."""
        conn = self._conn()
        try:
            cur = conn.execute(
                "SELECT song_id, bpm, camelot_key, energy, spectral_centroid, "
                "duration, tail_silence, data_version, phrase_positions "
                "FROM analysis_cache"
            )
            results = []
            for row in cur.fetchall():
                result = {
                    "song_id": row[0],
                    "bpm": row[1],
                    "key": row[2],
                    "energy": row[3],
                    "spectral_centroid": row[4],
                    "duration": row[5],
                    "tail_silence": row[6] if row[6] is not None else 0.0,
                    "data_version": row[7],
                }
                if row[8] is not None:
                    try:
                        result["phrase_positions"] = json.loads(row[8])
                    except (json.JSONDecodeError, TypeError):
                        pass
                results.append(result)
            return results
        finally:
            conn.close()
