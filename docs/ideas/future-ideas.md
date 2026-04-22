# Future ideas (parking lot)

Things that came up during planning that aren't in the active three-pass plan but we don't want to forget.

## Recommendations — "not interested" dismissals

Long-press or 3-dot-menu → "not interested" on a recommendation card. Dismissed Deezer track IDs persist across sessions (small Drift table: `dismissed_recommendations(deezer_id PRIMARY KEY, dismissed_at)`) and the recommendations pipeline excludes them forever.

- Out of scope for Pass 2a per user decision 2026-04-21.
- Revisit after Pass 2 / 3 ship if the user wants finer-grained taste steering.
- Table also useful for a future "undo" / "reset dismissals" affordance.

---

*Append new ideas here as they come up.*
