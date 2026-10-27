# Design conventions

Melodize follows Material 3 Expressive. These rules keep screens consistent; check new UI against
them.

## Color

- `AppTheme` builds light and dark schemes with `DynamicSchemeVariant.expressive`; on Android 12+
  the seed comes from the wallpaper (`DynamicColorBuilder`).
- Now Playing, the queue and the mini player take an accent from the current cover
  (`palette_generator`, `currentAccentColorProvider`); `foregroundAccentColor()` keeps it readable
  on the active brightness.
- Transparency: `.withValues(alpha:)`, never the deprecated `.withOpacity()`.

## Shape

| Element | Radius |
|---|---|
| Cover thumbnails (`CoverArtImage`, always use it; `externalUrl:` for Deezer art) | 8 |
| Cards, banners, grouped-list sections | 16 |
| Bottom sheets (theme default; no hand-made `Material(borderRadius:)`) | 28 top |
| Floating dock | 16, selection pill 19 (a stadium on its 38 px height) |
| Mini player | paused: 28 pill with a round thumbnail; playing: 16 card with a 10 thumbnail |

## Type

Use the theme's text styles, never a raw `fontSize:`. Section headers and detail-screen titles
are `titleLarge` in bold (the artist header: `headlineSmall`).

## App bars

- Tab roots and sub-pages: `SliverAppBar.medium`.
- Album, artist and playlist detail screens: a full-bleed cover-art `SliverAppBar` with
  `flexibleSpace`. Intentional; keep it.
- Home has no collapsing bar. M3's medium and large bars bottom-align the title, which left a
  ~100 px gap under the Android status bar (tried and reverted in v1.9.9). A second attempt must
  move the title inside the flexible space.

## Motion

Home sections enter with a staggered fade and slide on the M3 emphasized-decelerate curve
(`Cubic(0.05, 0.7, 0.1, 1.0)`, 400 ms). Scroll physics follow the platform: bouncing on desktop,
clamping on Android.
