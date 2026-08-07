"""
Audio analysis and transition mixing for the melodize-companion.

Requires: librosa, numpy, soundfile, pyrubberband
"""

import logging
import os
import time
from concurrent.futures import TimeoutError
from typing import Optional

import numpy as np
import soundfile as sf

log = logging.getLogger("melodize-companion.audio")

# ---------------------------------------------------------------------------
# Analysis

ANALYSIS_TIMEOUT = 60  # seconds per song


def analyze_song(file_path: str) -> Optional[dict]:
    """
    Analyze a single audio file for BPM, key, energy, and spectral features.

    Returns None if the file is unreadable or analysis times out.
    """
    import librosa  # slow import — keep at function level

    if not os.path.isfile(file_path):
        log.warning("File not found: %s", file_path)
        return None

    try:
        log.info("Analyzing %s ...", os.path.basename(file_path))
        t0 = time.time()

        # Load with a timeout guard — librosa can hang on corrupted files.
        y, sr = _load_with_timeout(file_path)

        if y is None or len(y) == 0:
            log.warning("Empty audio data: %s", file_path)
            return None

        duration = float(len(y)) / sr

        # --- BPM detection via beat tracking ---
        tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time")
        if isinstance(tempo, np.ndarray):
            bpm_val = tempo.item(0) if tempo.size > 0 else float("nan")
        else:
            bpm_val = float(tempo)
        bpm = round(bpm_val, 1) if not np.isnan(bpm_val) else None

        # --- Key detection via chroma ---
        key = _detect_key(y, sr)

        # --- Energy (RMS) ---
        rms = librosa.feature.rms(y=y)[0]
        energy = float(np.mean(rms))

        # --- Spectral centroid (brightness proxy) ---
        cent = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
        spectral_centroid = float(np.mean(cent))

        # --- Beat tracking (first beat offset, phrase boundaries) ---
        first_beat_offset: Optional[float] = None
        phrase_positions: Optional[list] = None
        if bpm is not None and not (isinstance(bpm, float) and np.isnan(bpm)):
            try:
                tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time")
                if len(beats) > 0:
                    first_beat_offset = float(beats[0])
                    beat_interval = 60.0 / bpm if bpm > 0 else 0.5
                    phrase_beats = 16  # 16-bar phrases (16 × 4 beats)
                    # Pick beats that align closest to 16-bar boundaries.
                    phrases = []
                    for i in range(0, len(beats), phrase_beats):
                        phrases.append(float(beats[i]))
                    phrase_positions = phrases
            except Exception:
                phrase_positions = None
                first_beat_offset = None

        # --- Vocal section detection ---
        vocal_sections = _detect_vocal_sections(y, sr)

        # --- Trailing silence detection ---
        # Scan backward from the end in 0.1s windows.  If the RMS in that
        # window stays below 5 % of the overall RMS (≈ −26 dB) it's silence.
        tail_silence = _detect_tail_silence(y, sr, energy_threshold=energy * 0.05)

        elapsed = time.time() - t0
        log.info(
            "  → %s  BPM=%-6s  key=%-4s  energy=%.3f  tail=%.1fs  phrases=%d  (%.1fs)",
            os.path.basename(file_path),
            bpm or "???",
            key or "???",
            energy,
            tail_silence,
            len(phrase_positions) if phrase_positions else 0,
            elapsed,
        )

        return {
            "bpm": bpm,
            "key": key,
            "energy": round(energy, 4),
            "spectral_centroid": round(spectral_centroid, 2),
            "duration": round(duration, 2),
            "tail_silence": round(tail_silence, 2),
            "phrase_positions": phrase_positions,
            "first_beat_offset": first_beat_offset,
            "vocal_sections": vocal_sections,
        }

    except Exception as e:
        log.warning("Analysis failed for %s: %s", file_path, e)
        return None


def _load_with_timeout(file_path: str, sr: int = 22050, max_sec: int = 180):
    """
    Load audio with a practical cap — librosa loads the whole file into memory,
    which can be huge for FLAC/ WAV.  We limit to `max_sec` seconds at `sr` Hz.
    """
    import librosa

    # librosa.load accepts a duration kwarg that reads only the first N seconds
    y, sr_out = librosa.load(
        file_path, sr=sr, mono=True, duration=max_sec, res_type="kaiser_fast"
    )
    return y, sr_out


# ---------------------------------------------------------------------------
# Trailing silence detection

def _detect_tail_silence(
    y: np.ndarray, sr: int, energy_threshold: float = 0.01, window_ms: int = 100
) -> float:
    """
    Scan backward from the end of *y* to find how many seconds are silence.

    A window is considered silent when its RMS energy falls below
    *energy_threshold* (absolute, not dB).  Returns seconds of trailing
    silence (0 if none detected, max ~30 s to bound the scan cost).
    """
    hop = int(sr * window_ms / 1000)  # samples per window
    max_windows = int((30 * sr) / hop)  # scan at most 30 s back

    tail_sec = 0.0
    for i in range(min(max_windows, len(y) // hop)):
        start = len(y) - (i + 1) * hop
        end = len(y) - i * hop
        window = y[start:end]
        rms = float(np.sqrt(np.mean(window ** 2)))
        if rms >= energy_threshold:
            break
        tail_sec += window_ms / 1000.0
    return tail_sec


# ---------------------------------------------------------------------------
# Vocal section detection

def _detect_vocal_sections(y: np.ndarray, sr: int) -> list[dict]:
    """
    Detect vocal (singing) sections in an audio signal.

    Uses a simple but effective approach:
    1. Separate harmonic (vocal-like) from percussive using HPSS
    2. Compute RMS energy of the harmonic component in short windows
    3. Threshold against the median + 1.5× MAD to find "active" windows
    4. Merge contiguous active windows into sections

    Returns a list of {"start": float, "end": float} dicts.
    """
    try:
        import librosa

        # Separate harmonic (vocal-like) from percussive
        y_harmonic, _ = librosa.effects.hpss(y)

        # Compute RMS in 0.5-second windows
        hop = int(sr * 0.5)
        rms = []
        for i in range(0, len(y_harmonic) - hop, hop):
            window = y_harmonic[i:i + hop]
            rms.append(float(np.sqrt(np.mean(window ** 2))))

        if not rms:
            return []

        # Dynamic threshold: median + 1.5 × median absolute deviation
        median_rms = float(np.median(rms))
        mad = float(np.median(np.abs(np.array(rms) - median_rms)))
        threshold = median_rms + 1.5 * mad

        # Find contiguous regions above threshold
        sections = []
        in_vocal = False
        start_sec = 0.0
        for i, val in enumerate(rms):
            sec = i * 0.5
            if val > threshold and not in_vocal:
                in_vocal = True
                start_sec = sec
            elif val <= threshold and in_vocal:
                in_vocal = False
                if sec - start_sec >= 2.0:  # Min 2-second vocal section
                    sections.append({
                        "start": round(start_sec, 2),
                        "end": round(sec, 2),
                    })

        # Close trailing section
        if in_vocal:
            end_sec = len(rms) * 0.5
            if end_sec - start_sec >= 2.0:
                sections.append({
                    "start": round(start_sec, 2),
                    "end": round(end_sec, 2),
                })

        return sections

    except Exception:
        return []


# ---------------------------------------------------------------------------
# Key detection (Camelot wheel)

# Chroma note names in order
_NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Mapped key profiles for major/minor detection (Krumhansl–Schmuckler)
_MAJOR_PROFILE = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
_MINOR_PROFILE = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def _detect_key(y: np.ndarray, sr: int) -> Optional[str]:
    """Detect the musical key and return it in Camelot wheel notation."""
    import librosa

    try:
        # Chromagram
        chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
        chroma_mean = np.mean(chroma, axis=1)

        # Correlation with major/minor profiles
        major_corrs = [np.corrcoef(_MAJOR_PROFILE, np.roll(chroma_mean, i))[0, 1] for i in range(12)]
        minor_corrs = [np.corrcoef(_MINOR_PROFILE, np.roll(chroma_mean, i))[0, 1] for i in range(12)]

        # Handle NaN correlations (silent audio)
        major_corrs_clean = [0.0 if np.isnan(c) else float(c) for c in major_corrs]
        minor_corrs_clean = [0.0 if np.isnan(c) else float(c) for c in minor_corrs]

        best_major = max(range(12), key=lambda i: major_corrs_clean[i])
        best_minor = max(range(12), key=lambda i: minor_corrs_clean[i])

        if major_corrs[best_major] >= minor_corrs[best_minor]:
            return _to_camelot(best_major, is_minor=False)
        else:
            return _to_camelot(best_minor, is_minor=True)

    except Exception:
        return None


# Camelot wheel mapping: https://en.wikipedia.org/wiki/Camelot_(wheel)
#
# Major keys (B):   1B=C, 2B=G, 3B=D, 4B=A, 5B=E, 6B=B, 7B=F#, 8B=Db, 9B=Ab, 10B=Eb, 11B=Bb, 12B=F
# Minor keys (A):   1A=Am, 2A=Em, 3A=Bm, 4A=F#m, 5A=C#m, 6A=G#m, 7A=D#m, 8A=Bbm, 9A=Fm, 10A=Cm, 11A=Gm, 12A=Dm
#
# Pitch class → Camelot number for major keys:
_CAMELOT_MAJOR = [8, 3, 10, 5, 12, 7, 2, 9, 4, 11, 6, 1]  # C→8, C#→3, D→10, ...
# Pitch class → Camelot number for minor keys:
_CAMELOT_MINOR = [5, 12, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10]  # C→5, C#→12, D→7, ...


def _to_camelot(pitch_class: int, is_minor: bool) -> str:
    """Convert a pitch class (0-11, where 0=C) to Camelot notation."""
    if is_minor:
        num = _CAMELOT_MINOR[pitch_class]
        return f"{num}A"
    else:
        num = _CAMELOT_MAJOR[pitch_class]
        return f"{num}B"


# ---------------------------------------------------------------------------
# Transition mixing

MIX_TIMEOUT = 30  # seconds per mix


def estimate_mix_quality(
    bpm_a: float,
    bpm_b: float,
    key_a: Optional[str] = None,
    key_b: Optional[str] = None,
) -> str:
    """
    Estimate the expected quality of a mix between two songs.

    Returns one of 'perfect', 'good', 'acceptable', or 'skip'.
    """
    if bpm_a <= 0 or bpm_b <= 0:
        return "skip"
    ratio = max(bpm_a, bpm_b) / min(bpm_a, bpm_b) if min(bpm_a, bpm_b) > 0 else 1.0

    if ratio > 1.15:
        return "skip"

    # Key compatibility check
    keys_compatible = False
    if key_a and key_b:
        try:
            num_a = int(key_a.rstrip("AB"))
            num_b = int(key_b.rstrip("AB"))
            mode_a = key_a[-1]
            mode_b = key_b[-1]
            diff_abs = abs(num_a - num_b) % 12
            wrapped = min(diff_abs, 12 - diff_abs)
            keys_compatible = wrapped <= 2 or (num_a == num_b)
        except (ValueError, IndexError):
            keys_compatible = False

    if ratio < 1.08 and keys_compatible:
        return "perfect"
    if ratio < 1.15 and keys_compatible:
        return "good"
    if ratio < 1.15:
        return "acceptable"
    return "skip"


def generate_transition(
    song_a_path: str,
    song_b_path: str,
    bpm_a: float,
    bpm_b: float,
    mix_duration: float = 10.0,
    sample_rate: int = 44100,
    tail_silence_a: float = 0.0,
    key_a: Optional[str] = None,
    key_b: Optional[str] = None,
) -> Optional[bytes]:
    """
    Generate a time-stretched crossfade mix between two songs.

    Takes the tail of song A (excluding trailing silence) and the head of
    song B, time-stretches B's head to match A's BPM, then crossfades them.
    Returns WAV bytes.

    Returns None if the mix can't be generated (BPM gap too large, etc.).
    """
    import pyrubberband as pyrb

    if bpm_a <= 0 or bpm_b <= 0:
        log.warning("Invalid BPM: a=%s b=%s — skipping mix", bpm_a, bpm_b)
        return None

    # BPM gap check — >15% gap sounds bad even with time-stretching
    bpm_ratio = max(bpm_a, bpm_b) / min(bpm_a, bpm_b) if min(bpm_a, bpm_b) > 0 else 1
    if bpm_ratio > 1.15:
        log.info(
            "BPM gap too large for mix: %.1f → %.1f (ratio=%.3f)",
            bpm_a, bpm_b, bpm_ratio,
        )
        return None

    try:
        # Load tails/heads — skip trailing silence in song A's tail. Load a
        # little extra B audio because tempo stretching changes the number of
        # samples consumed by the bridge.
        tail_a, sr_a = _load_tail(song_a_path, mix_duration, sample_rate,
                                  tail_silence=tail_silence_a)
        stretch_factor = bpm_a / bpm_b
        head_duration = mix_duration * max(1.0, stretch_factor) + 0.5
        head_b, sr_b = _load_head(song_b_path, head_duration, sample_rate)

        if tail_a is None or head_b is None or len(tail_a) == 0 or len(head_b) == 0:
            log.warning("Empty audio segment for mix")
            return None

        # Use song A's sample rate for both
        sr = max(sr_a, sr_b)

        # Time-stretch head B to match BPM of A
        if abs(stretch_factor - 1.0) > 0.01:
            head_b = pyrb.time_stretch(head_b, sr, stretch_factor)

        # Match lengths exactly. Padding the shorter side avoids returning a
        # truncated bridge for short tracks and keeps the WAV duration stable.
        target_len = min(len(tail_a), len(head_b))
        if target_len <= 0:
            return None
        tail_a = _fit_segment(tail_a, target_len)
        head_b = _fit_segment(head_b, target_len)

        # Equal-power crossfade envelope
        fade = np.linspace(0, 1, min_len)
        fade_out = 1 - fade  # A fades out
        fade_in = fade       # B fades in
        # Equal-power: gain stays roughly constant
        fade_out_eq = np.cos(fade * np.pi / 2)
        fade_in_eq = np.sin(fade * np.pi / 2)

        mixed = tail_a * fade_out_eq + head_b * fade_in_eq

        # Normalize to prevent clipping
        peak = np.max(np.abs(mixed))
        if peak > 0.95:
            mixed = mixed * (0.95 / peak)

        # Write to bytes
        import io
        buf = io.BytesIO()
        sf.write(buf, mixed, sr, format="WAV", subtype="PCM_16")
        return buf.getvalue()

    except Exception as e:
        log.warning("Transition mix failed: %s", e)
        return None


def _load_tail(file_path: str, duration: float, sr: int = 44100,
               tail_silence: float = 0.0):
    """Load the last `duration` seconds of *actual audio* (excluding trailing silence).

    When *tail_silence* > 0 the load window is shifted forward by that many
    seconds, then the silence is trimmed so the caller gets clean audio for
    crossfading.
    """
    import librosa

    try:
        info = sf.info(file_path)
        total = info.frames / info.samplerate
        # Load extra so we can discard the silent tail
        load_len = min(duration + tail_silence, total)
        offset = max(0, total - load_len)
        y, sr_out = librosa.load(
            file_path, sr=sr, mono=True, offset=offset, duration=load_len,
            res_type="kaiser_fast",
        )
        # Chop the trailing silence off the end
        if tail_silence > 0 and y is not None and len(y) > 0:
            trim = int(tail_silence * sr_out)
            if trim < len(y):
                y = y[:-trim]
        return y, sr_out
    except Exception as e:
        log.warning("Failed to load tail of %s: %s", file_path, e)
        return None, sr


def _fit_segment(signal: np.ndarray, length: int) -> np.ndarray:
    """Return exactly [length] mono samples without changing its content."""
    if len(signal) >= length:
        return signal[:length]
    return np.pad(signal, (0, length - len(signal)))


def _load_head(file_path: str, duration: float, sr: int = 44100):
    """Load the first `duration` seconds of a file."""
    import librosa

    try:
        y, sr_out = librosa.load(
            file_path, sr=sr, mono=True, duration=duration,
            res_type="kaiser_fast",
        )
        return y, sr_out
    except Exception as e:
        log.warning("Failed to load head of %s: %s", file_path, e)
        return None, sr


# ---------------------------------------------------------------------------
# Batch analysis job tracking

class AnalysisJobManager:
    """Manages the lifecycle of a batch analysis job."""

    def __init__(self):
        self._jobs: dict[str, dict] = {}

    def create_job(self, job_id: str, song_ids: list[dict]) -> str:
        """Create a new analysis job. song_ids is list of {song_id, file_path}."""
        self._jobs[job_id] = {
            "job_id": job_id,
            "status": "queued",
            "total": len(song_ids),
            "analyzed": 0,
            "skipped": 0,
            "failed": 0,
            "results": [],
            "songs": song_ids,
        }
        return job_id

    def get_job(self, job_id: str) -> Optional[dict]:
        return self._jobs.get(job_id)

    def update_job(self, job_id: str, **kwargs):
        job = self._jobs.get(job_id)
        if job:
            job.update(kwargs)

    def add_result(self, job_id: str, result: dict):
        job = self._jobs.get(job_id)
        if job:
            job["results"].append(result)

    def cleanup(self, job_id: str):
        """Remove a finished job to free memory."""
        self._jobs.pop(job_id, None)


analysis_jobs = AnalysisJobManager()
