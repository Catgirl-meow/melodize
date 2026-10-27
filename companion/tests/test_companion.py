"""Tests for melodize-companion.

Run from the repo root:
    uv run --no-project --with numpy --with soundfile --with librosa \
        --with pyrubberband python -m unittest discover -s companion/tests -v

librosa/pyrubberband are only needed for the transition-mix test, which is
skipped when they are missing.
"""

import importlib.machinery
import importlib.util
import json
import os
import pathlib
import socket
import sqlite3
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

COMPANION_DIR = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(COMPANION_DIR))

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402

from analysis_cache import AnalysisCache  # noqa: E402
import audio_analysis  # noqa: E402


def _load_companion():
    path = COMPANION_DIR / "melodize-companion"
    loader = importlib.machinery.SourceFileLoader("melodize_companion", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


companion = _load_companion()

API_KEY = "k" * 64
VALID_ARL = "a1b2c3" * 30


class UrlValidationTest(unittest.TestCase):
    def test_rejects_option_injection(self):
        for url in ("--exec=touch /tmp/pwned", "-o/etc/x", " --exec x"):
            self.assertIsNotNone(companion.validate_download_url(url.strip()), url)

    def test_rejects_non_http_schemes(self):
        for url in ("file:///etc/passwd", "ftp://x/y", "javascript:alert(1)", "deezer.com/track/1"):
            self.assertIsNotNone(companion.validate_download_url(url), url)

    def test_rejects_whitespace_and_control_chars(self):
        self.assertIsNotNone(companion.validate_download_url("https://a.com/x y"))
        self.assertIsNotNone(companion.validate_download_url("https://a.com/x\n--exec"))

    def test_rejects_overlong(self):
        self.assertIsNotNone(companion.validate_download_url("https://a.com/" + "x" * 3000))

    def test_accepts_normal_urls(self):
        for url in ("https://www.deezer.com/track/3135556",
                    "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    "http://example.org/a%20b.mp3"):
            self.assertIsNone(companion.validate_download_url(url), url)

    def test_deezer_detection_uses_host(self):
        self.assertTrue(companion.is_deezer_url("https://www.deezer.com/en/track/1"))
        self.assertTrue(companion.is_deezer_url("https://deezer.com/album/1"))
        self.assertTrue(companion.is_deezer_url("https://deezer.page.link/abc"))
        self.assertFalse(companion.is_deezer_url("https://evil.example/?u=deezer.com"))
        self.assertFalse(companion.is_deezer_url("https://notdeezer.com/track/1"))
        self.assertFalse(companion.is_deezer_url("https://deezer.com.evil.example/x"))

    def test_arl_validation(self):
        self.assertTrue(companion.is_valid_arl(VALID_ARL))
        self.assertFalse(companion.is_valid_arl(""))
        self.assertFalse(companion.is_valid_arl("short"))
        self.assertFalse(companion.is_valid_arl(VALID_ARL + "; sid=x"))
        self.assertFalse(companion.is_valid_arl(VALID_ARL + '"\nurl = "http://evil'))


class JobRegistryTest(unittest.TestCase):
    def test_old_jobs_are_pruned(self):
        companion._register_job("old", {"status": "done"})
        companion._job_created["old"] = time.time() - companion.JOB_TTL_SECONDS - 1
        companion._register_job("new", {"status": "queued"})
        self.assertNotIn("old", companion._jobs)
        self.assertIn("new", companion._jobs)

    def test_update_of_pruned_job_does_not_raise(self):
        companion._update_job("does-not-exist", status="done")

    def test_analysis_jobs_snapshot_and_prune(self):
        mgr = audio_analysis.AnalysisJobManager()
        mgr.create_job("j1", [{"song_id": "a"}])
        mgr.add_result("j1", {"song_id": "a", "bpm": 120})
        snap = mgr.get_job("j1")
        mgr.add_result("j1", {"song_id": "b"})
        self.assertEqual(len(snap["results"]), 1, "snapshot must not alias live list")
        mgr.prune(0)
        self.assertIsNotNone(mgr.get_job("j1"), "running jobs are kept")
        mgr.update_job("j1", status="done")
        mgr._created["j1"] -= 10
        mgr.prune(1)
        self.assertIsNone(mgr.get_job("j1"))


class AnalysisCacheTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = os.path.join(self.tmp.name, "cache.db")

    def tearDown(self):
        self.tmp.cleanup()

    def test_roundtrip_returns_named_fields(self):
        cache = AnalysisCache(self.db)
        cache.set("s1", "/m/a.flac", 1.5, 100,
                  {"bpm": 128.0, "key": "8A", "energy": 0.3, "tail_silence": 1.2,
                   "phrase_positions": [0.5, 8.0]})
        got = cache.get("s1")
        self.assertEqual(got["bpm"], 128.0)
        self.assertEqual(got["key"], "8A")
        self.assertEqual(got["tail_silence"], 1.2)
        self.assertEqual(got["data_version"], 3)
        self.assertEqual(got["phrase_positions"], [0.5, 8.0])
        self.assertRegex(got["analyzed_at"], r"^\d{4}-\d\d-\d\d")

    def test_migrated_column_order(self):
        # A v1 database: tail_silence/phrase_positions were added later with
        # ALTER TABLE, so they sit after analyzed_at physically.
        conn = sqlite3.connect(self.db)
        conn.executescript("""
            CREATE TABLE analysis_cache (
                song_id TEXT PRIMARY KEY, file_path TEXT NOT NULL,
                file_mtime REAL NOT NULL, file_size INTEGER NOT NULL,
                bpm REAL, camelot_key TEXT, energy REAL, spectral_centroid REAL,
                duration REAL, data_version INTEGER DEFAULT 1,
                analyzed_at TEXT NOT NULL DEFAULT (datetime('now')));
        """)
        conn.close()
        cache = AnalysisCache(self.db)
        cache.set("s1", "/m/a.flac", 1.0, 1, {"bpm": 100.0, "tail_silence": 2.0})
        got = cache.get("s1")
        self.assertEqual(got["tail_silence"], 2.0)
        self.assertEqual(got["data_version"], 3)
        self.assertRegex(got["analyzed_at"], r"^\d{4}-")

    def test_get_all_stale(self):
        cache = AnalysisCache(self.db)
        cache.set("s1", "/m/a", 1.0, 10, {"bpm": 1})
        cache.set("s2", "/m/b", 1.0, 10, {"bpm": 1})
        songs = [
            {"song_id": "s1", "file_path": "/m/a", "mtime": 1.0, "size": 10},   # fresh
            {"song_id": "s2", "file_path": "/m/b", "mtime": 2.0, "size": 10},   # touched
            {"song_id": "s3", "file_path": "/m/c", "mtime": 1.0, "size": 10},   # new
        ]
        stale = [s["song_id"] for s in cache.get_all_stale(songs)]
        self.assertEqual(stale, ["s2", "s3"])


def _sine(path, seconds, freq=440.0, sr=44100):
    t = np.arange(int(seconds * sr)) / sr
    sf.write(path, 0.3 * np.sin(2 * np.pi * freq * t), sr)


class TransitionTest(unittest.TestCase):
    def test_generate_transition_returns_wav(self):
        try:
            import librosa  # noqa: F401
            import pyrubberband  # noqa: F401
        except ImportError:
            self.skipTest("librosa/pyrubberband not installed")
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, "a.wav"), os.path.join(d, "b.wav")
            _sine(a, 20, 440)
            _sine(b, 20, 660)
            # Same BPM: no time-stretch, so the rubberband binary isn't needed.
            wav = audio_analysis.generate_transition(a, b, 120.0, 120.0, 6.0)
            self.assertIsNotNone(wav, "mix generation must not fail")
            info = sf.info(__import__("io").BytesIO(wav))
            self.assertAlmostEqual(info.frames / info.samplerate, 6.0, delta=0.1)

    def test_bpm_gap_too_large_falls_back(self):
        try:
            import pyrubberband  # noqa: F401
        except ImportError:
            self.skipTest("pyrubberband not installed")
        self.assertIsNone(audio_analysis.generate_transition("/x", "/y", 90, 140, 6))


class ServerTest(unittest.TestCase):
    """Runs the real HTTP server on an ephemeral port against a fake library."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(cls.tmp.name)
        cls.music = root / "music"
        cls.music.mkdir()
        (root / "outside.txt").write_text("keep me")
        db = root / "navidrome.db"
        conn = sqlite3.connect(db)
        conn.execute("CREATE TABLE media_file (id TEXT PRIMARY KEY, path TEXT)")
        conn.executemany("INSERT INTO media_file VALUES (?, ?)", [
            ("song1", "Artist/song1.flac"),
            ("escape", "../outside.txt"),
            ("gone", "Artist/missing.flac"),
            ("mixA", "Artist/a.wav"),
            ("mixB", "Artist/b.wav"),
        ])
        conn.commit()
        conn.close()
        (cls.music / "Artist").mkdir()
        cfg = {
            "api_key": API_KEY,
            "music_dir": str(cls.music),
            "navidrome_db": str(db),
            "analysis_cache_path": str(root / "state" / "cache.db"),
            "mix_cache_dir": str(root / "mix"),
        }
        cls.root = root
        cls.srv = companion._Server(("127.0.0.1", 0), companion._Handler, cfg)
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()
        cls.tmp.cleanup()

    def req(self, method, path, body=None, key=API_KEY, raw=None, headers=None):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        r = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}", data=data, method=method)
        if key is not None:
            r.add_header("X-API-Key", key)
        for k, v in (headers or {}).items():
            r.add_header(k, v)
        try:
            with urllib.request.urlopen(r, timeout=5) as resp:
                return resp.status, resp.headers, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, e.headers, e.read()

    def test_health_is_public(self):
        code, _, body = self.req("GET", "/health", key=None)
        self.assertEqual(code, 200)
        self.assertEqual(json.loads(body)["status"], "ok")

    def test_auth_required(self):
        for path in ("/api/audio/analysis", "/api/songs/download/abc"):
            self.assertEqual(self.req("GET", path, key=None)[0], 403)
            self.assertEqual(self.req("GET", path, key="wrong")[0], 403)
        self.assertEqual(self.req("DELETE", "/api/songs/song1", key=None)[0], 403)
        self.assertTrue((self.music / "Artist").exists())

    def test_non_ascii_key_is_rejected_not_crashing(self):
        # http.client refuses non-latin-1 header values, so send raw bytes.
        with socket.create_connection(("127.0.0.1", self.port), timeout=5) as s:
            s.sendall(b"GET /api/audio/analysis HTTP/1.1\r\nHost: x\r\n"
                      b"X-API-Key: \xc3\xa9\xc3\xa9\r\nConnection: close\r\n\r\n")
            resp = s.recv(4096)
        self.assertIn(b" 403 ", resp.split(b"\r\n")[0])

    def test_delete_and_traversal(self):
        f = self.music / "Artist" / "song1.flac"
        f.write_bytes(b"x")
        self.assertEqual(self.req("DELETE", "/api/songs/song1")[0], 200)
        self.assertFalse(f.exists())
        code, _, _ = self.req("DELETE", "/api/songs/escape")
        self.assertEqual(code, 403)
        self.assertTrue((self.root / "outside.txt").exists())
        self.assertEqual(self.req("DELETE", "/api/songs/gone")[0], 200)
        self.assertEqual(self.req("DELETE", "/api/songs/nope")[0], 404)

    def test_download_rejects_injection(self):
        for url in ("--exec=touch /tmp/pwned", "file:///etc/passwd", "https://a.com/ x"):
            code, _, body = self.req("POST", "/api/songs/download", {"url": url})
            self.assertEqual(code, 400, url)
        code, _, _ = self.req("POST", "/api/songs/download",
                              {"url": "https://www.deezer.com/track/1", "deezer_arl": "x; y"})
        self.assertEqual(code, 400)

    def test_bad_bodies(self):
        self.assertEqual(self.req("POST", "/api/songs/download", raw=b"[1,2]")[0], 400)
        self.assertEqual(self.req("POST", "/api/songs/download", raw=b"{not json")[0], 400)
        self.assertEqual(self.req("POST", "/api/songs/download", {"url": 5})[0], 400)
        self.assertEqual(self.req("POST", "/api/audio/mix-transition",
                                  {"song_a_id": 1, "song_b_id": None})[0], 400)
        self.assertEqual(self.req("POST", "/api/audio/mix-transition",
                                  {"song_a_id": "a", "song_b_id": "b", "mix_duration": "nan"})[0], 400)
        self.assertEqual(self.req("POST", "/api/audio/analyze-batch",
                                  {"song_ids": "song1"})[0], 400)
        self.assertEqual(self.req("POST", "/api/audio/analyze-batch",
                                  {"song_ids": [1, 2]})[0], 400)

    def test_oversized_body_rejected_without_reading(self):
        with socket.create_connection(("127.0.0.1", self.port), timeout=5) as s:
            s.sendall(("POST /api/songs/download HTTP/1.1\r\nHost: x\r\n"
                       f"X-API-Key: {API_KEY}\r\nContent-Length: 999999999\r\n"
                       "Connection: close\r\n\r\n").encode())
            resp = s.recv(4096)
        self.assertIn(b" 400 ", resp.split(b"\r\n")[0])

    def test_slow_client_does_not_block_others(self):
        # A client that opens a connection and never finishes its request used
        # to stall the single-threaded server for everyone.
        slow = socket.create_connection(("127.0.0.1", self.port), timeout=5)
        try:
            slow.sendall(b"GET /health HTTP/1.1\r\n")
            t0 = time.time()
            code, _, _ = self.req("GET", "/health", key=None)
            self.assertEqual(code, 200)
            self.assertLess(time.time() - t0, 2)
        finally:
            slow.close()

    def test_analyze_batch_large_id_list(self):
        ids = [f"id{i}" for i in range(5000)] + ["song1"]
        code, _, body = self.req("POST", "/api/audio/analyze-batch", {"song_ids": ids})
        self.assertIn(code, (200, 202))

    def test_transition_file_is_private(self):
        mix = self.root / "mix"
        mix.mkdir(exist_ok=True)
        (mix / "abc123.wav").write_bytes(b"RIFF" + b"\0" * 100)
        code, headers, body = self.req("GET", "/api/audio/transition/abc123.wav")
        self.assertEqual(code, 200)
        self.assertEqual(len(body), 104)
        self.assertTrue(headers["Cache-Control"].startswith("private"))
        self.assertEqual(self.req("GET", "/api/audio/transition/abc123.wav", key=None)[0], 403)
        self.assertEqual(self.req("GET", "/api/audio/transition/..%2Fx.wav")[0], 404)

    def test_mix_unknown_song(self):
        code, _, _ = self.req("POST", "/api/audio/mix-transition",
                              {"song_a_id": "nope", "song_b_id": "mixB"})
        self.assertEqual(code, 404)


if __name__ == "__main__":
    unittest.main()
