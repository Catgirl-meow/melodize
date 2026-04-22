# 2f — Mini-player + dock design fixes

**Goal:** Reconcile the two mini-player variants, fix the shape morph that "looks horrible", review the floating dock so it's not "partly horrible", make the grouped settings tiles look right.

User quote: *"Horrible design in some places like mini player, menus and some other stuff ... new dock which is partly horrible. The old dock can be btw enabled in settings."*

## Current state

**Files:**
- `lib/features/player/mini_player.dart` — routes to `FloatingMiniPlayer` or `_ClassicMiniPlayer` based on `preferences.floatingNavBar`.
- `lib/features/player/widgets/floating_mini_player.dart` — the floating-dock variant (with shape morph, radius 28 ↔ 10).
- `lib/features/shell/main_shell.dart` — renders `MiniPlayer`, hosts the floating dock / classic `NavigationBar`.
- `lib/features/home/home_screen.dart`, `lib/features/library/*`, `lib/features/settings/settings_screen.dart` — app-bar heights + geometry.
- `lib/features/settings/settings_screen.dart` — grouped tiles (Android 15 style).

## Problems to probe (ask user for screenshots)

1. Shape-morph radii/curve feel wrong (too harsh? too soft? morph too fast / slow?).
2. Thumbnail morph: radius of the cover art inside the mini player changes with play/pause — is the paired motion distracting?
3. Dock ↔ mini-player gap / alignment when floating dock is on.
4. Grouped settings tiles — spacing, corner radii, tap targets.
5. App-bar heights on Home / Library / Settings — still odd after recent SliverAppBar removal commits?

## Proposal (placeholder — needs screenshot-driven iteration)

- Design review session with user → capture specific screens.
- Pick a single shape-morph language and apply consistently to both mini-player variants.
- Rework floating-dock geometry (height, corner radius, horizontal insets, elevation).
- Tweak grouped-tile spacing (internal 4 px, external 12 px type of decision).

## Open questions
- Fixed-pixel values or motion tokens (deferred to Pass 3 item 06)?
- Accept-or-reject the `FloatingMiniPlayer` entirely and fold it back into one unified design?

## Files to touch
- Mini-player widgets (both).
- Main shell.
- Settings screen (tile spacing).
- App bar usages across Home / Library / Settings.

## Verification
- Device QA with screenshots side-by-side vs current build.
- User approval round by round.

## Status
- 2026-04-21: pending. Needs user screenshots to start.
- 2026-04-22: **first pass shipped (v1.8.4)** — shape-morph radius consistency + dock pill geometry. Changes:
  - `floating_mini_player.dart`: playing card radius 10 → **16** (matches `_kDockRadius`); thumb playing 6 → **10** (≈ half the card radius); shadow moved into the `AnimatedContainer.decoration` so it morphs in lockstep with the card instead of sitting at a fixed mismatched radius mid-transition.
  - `main_shell.dart`: selection pill decoupled from `_kDockRadius` — new `_kPillRadius = 19` renders a true stadium on the 38 px pill (height/2); horizontal pill inset 4 → **10** so the pill floats inside the cell instead of filling it.
  - Result shape language: dock 16 / pill 19-stadium / mini-player paused 28-pill (thumb 20-circle) / mini-player playing 16-card (thumb 10).
- Still pending: grouped-settings-tile visual pass (2f item 4), app-bar geometry review (item 5), classic (non-floating) mini-player — user flagged the floating one specifically, classic left alone.
