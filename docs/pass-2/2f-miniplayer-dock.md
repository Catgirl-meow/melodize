# 2f — Mini-player + dock design fixes

**Goal:** Fix shape morph and floating dock geometry. Grouped settings tiles visual pass.

## Status

- **v1.8.4** — Shape-morph radius consistency + dock pill geometry shipped:
  - `floating_mini_player.dart`: playing card radius 10 → **16**; thumb radius 6 → **10**; shadow moved into `AnimatedContainer.decoration` so it morphs with the card.
  - `main_shell.dart`: selection pill radius decoupled from dock radius — `_kPillRadius = 19` (true stadium on 38 px height); horizontal inset 4 → **10**.
  - Shape language: dock 16 / pill 19-stadium / mini-player paused 28-pill (thumb 20-circle) / mini-player playing 16-card (thumb 10).

## Remaining

- Grouped settings tiles spacing, corner radii, tap targets
- App-bar geometry review (Home / Library / Settings)
- Classic mini-player review (floating variant was the problematic one)

## Files

- `lib/features/player/mini_player.dart`
- `lib/features/player/widgets/floating_mini_player.dart`
- `lib/features/shell/main_shell.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/library/library_screen.dart`
