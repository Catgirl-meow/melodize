# 2h — Smart shuffle + playback architecture rework

**Status:** ✅ Implemented (May 2026)

## Motivation

The old `audio_handler.dart` was a ~900-line monolith with queue state,
shuffle, crossfade, and transition mixing all intertwined. Problems:

1. WAV-based transition mixing broke queue indices and produced poor results.
2. Smart shuffle was imperceptible — greedy TSP minimized BPM/key distance
   but produced a flat energy curve indistinguishable from random shuffle.
3. No single queue snapshot for UI — multiple ad-hoc streams.
4. Queue mutations (`playNext`, `addToQueue`, `removeFromQueue`) silently
   cleared shuffle state, reverting to sequential playback.
5. Crossfade loaded the physically-adjacent song, ignoring shuffle order.

---

## New architecture

```
MelodizeAudioHandler (audio_handler.dart)  —  Plumbing layer
    │  Owns just_audio AudioPlayer, audio_service BaseAudioHandler,
    │  ConcatenatingAudioSource.  Routes media key events.
    │
    ├── PlaybackQueue (playback_core.dart)  —  Logical queue model
    │      Mirrors the physical ConcatenatingAudioSource.
    │      All mutations (playNext, add, removeAt, reorder) go
    │      through here so the logical index stays in sync.
    │      Produces snapshots for UI consumption.
    │
    ├── PlaybackPlanner (playback_core.dart)  —  Song order planner
    │      Given songs + mode (normal/shuffle/smartShuffle),
    │      returns a planned order.  Preserves heard songs in
    │      place; only reorders upcoming songs.
    │      Delegates to smart_shuffle_engine.dart for DJ-aware
    │      ordering (beatmatch + Camelot key + genre + energy).
    │
    └── TransitionPolicy (playback_core.dart)  —  Transition planner
           Plans what happens between each pair of songs:
           • gapless        — no transition (crossfade disabled, short
                               track, offline fallback, unknown duration)
           • volumeCrossfade — standard fade between tracks
           • djBlend         — compatible BPM + real companion analysis;
                                could enable time-stretched blending
           Generates PlannedTransition with precise timing (fromStart,
           toStart, duration) for the deck-based crossfade engine.
```

### Key design decisions

**Logical queue mirror.** `PlaybackQueue` keeps a `List<Song>` in sync with
`ConcatenatingAudioSource`. Mutations update both and regenerate the shuffle
virtual order instead of clearing it.

**DJ-aware smart shuffle.** Replaced greedy TSP with a multi-component scorer:

| Component | Weight | Source |
|-----------|--------|--------|
| BPM match | ~0.35 | Companion (real) or Deezer/estimate |
| Camelot key | ~0.25 | Companion analysis |
| Genre family | ~0.25 | 7 DJ-compatible groups |
| Energy proximity | ~0.15 | Companion RMS |
| Artist penalty | multiplies by 0.1 | — |

Songs are bucketed into 5 energy tiers; the path follows a warm-up → peak →
cool-down arc. A 2-opt pass improves the result.

**DJ quality tiers** — auto-detected from available data:

| Tier | Data | Behavior |
|------|------|----------|
| Full DJ | Real BPM + key + energy | All scorers active |
| Partial DJ | Deezer BPM/energy (no keys) | BPM + genre; key weight redistributed |
| Simple DJ | Offline — genre + estimated BPM | Genre + wide BPM tolerance; warning shown |

**Heard-song preservation.** Toggling smart shuffle mid-playback keeps heard
songs in place; only upcoming tracks are reordered.

**Deck-based crossfade.** Follows virtual shuffle order. Skips when next song
would be `about:blank`. Reuses the `AudioPlayer` deck across transitions.
Queue snapshots debounce position updates (500 ms) and emit immediately on
mutations.

**Dead code removed.** `mix_transition_manager.dart` and `transition_plan.dart`
deleted.

---

## Files

| File | Status | Description |
|------|--------|-------------|
| `lib/core/audio/smart_shuffle_engine.dart` | **Rewritten** | DJ scoring (`_djScore`), energy-constrained arc builder (`_buildDjArc`), 3 quality tiers (`_detectDjTier`), 2-opt optimization. Preserved public API: `BpmCache`, `buildBpmCache`, `orderSongs`. |
| `lib/core/audio/playback_core.dart` | **NEW** | `PlaybackQueue`, `PlaybackPlanner`, `TransitionPolicy`, `PlaybackQueueSnapshot`, `PlannedTransition`, `PlaybackMode`, `TransitionKind` |
| `test/playback_core_test.dart` | **NEW** | Unit tests for planner (smart shuffle anchoring, shuffle preservation), transition policy (crossfade timing, gapless fallback, DJ blend criteria), and queue (index sync, snapshot) |
| `lib/core/audio/audio_handler.dart` | **Major rework** | Integrates `PlaybackQueue`/`PlaybackPlanner`/`TransitionPolicy`; deck-based crossfade with virtual order + offline safety + timer race guard + deck reuse + snapshot debounce; queue mutations regenerate shuffle order; deprecated `setTransitionMixManager` no-op |
| `lib/core/audio/mix_transition_manager.dart` | **DELETED** | WAV-based companion transition mixing — removed entirely |
| `lib/core/audio/transition_plan.dart` | **DELETED** | Old transition plan model — replaced by `TransitionPolicy` in `playback_core.dart` |
| `lib/core/models/app_preferences.dart` | Modified | Added `crossfadeSeconds` (0–12) and `djTransitionsEnabled` (bool) |
| `lib/core/providers.dart` | Modified | Added `queueSnapshotStreamProvider`, imports `playback_core.dart` |
| `lib/main.dart` | Modified | Wires crossfade + DJ transition prefs from settings; removed deprecated `TransitionMixManager` wiring |
| `lib/features/settings/settings_screen.dart` | Modified | Crossfade slider (0–8s) and DJ transitions toggle in Playback section |
| `lib/features/player/queue_screen.dart` | Modified | Uses `queueSnapshotStreamProvider` instead of ad-hoc handler reads |

---

## Preferences added

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `crossfadeSeconds` | int | 0 | Crossfade duration in seconds (0 = off, max 12). Persisted and restored on startup. |
| `djTransitionsEnabled` | bool | true | When enabled, tracks with real companion BPM analysis and compatible tempo (±15%) are marked as `djBlend` in `TransitionPolicy`. |

---

## Transition kinds

| Kind | Conditions | Behavior |
|------|-----------|----------|
| `gapless` | Crossfade disabled, track < 15s, unknown duration, or offline-fallback `about:blank` | No transition; next track starts immediately after current ends |
| `volumeCrossfade` | Crossfade > 0, track ≥ 15s, next song playable | Deck-based crossfade with volume ramp over the configured duration; offset by trailing silence so fade doesn't start during silence |
| `djBlend` | Crossfade > 0, both tracks have real companion BPM data, BPM ratio ≤ 1.15 | Same deck-based crossfade as `volumeCrossfade`, tagged for future DJ-engine enhancements |

---

## Bug fixes

1. Queue mutations regenerate shuffle order instead of clearing it.
2. Crossfade follows virtual shuffle order, not physical index + 1.
3. Offline safety — skips deck transition when next source would be `about:blank`.
4. Timer race condition fixed — checks `_deckTransitionActive` after async `setAudioSource`.
5. Deck reuse — `AudioPlayer` recycled across transitions.
6. Snapshot debounce — 500 ms on position stream, immediate on mutations.

---

## Verification

1. `flutter analyze` clean.
2. `flutter test test/playback_core_test.dart` — all 9 tests pass.
3. Shuffle → heard songs stay in place, upcoming songs reordered.
4. Toggle smart shuffle mid-playback → current song keeps playing.
5. Crossfade at 4 s → smooth volume crossfade.
6. Crossfade at 0 → gapless.
7. Queue screen shows correct list via `queueSnapshotStream`.
8. Pause/seek during crossfade → cancels cleanly.
9. Offline → Simple DJ tier still works; crossfade skips unplayable tracks.
10. Companion unreachable → Partial DJ tier, warning shown.
