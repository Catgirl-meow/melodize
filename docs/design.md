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
- `AppTheme.schemeFor()` fills the surface-container tones that Android's wallpaper scheme leaves
  unset (they default to `surface`, which made cards, grouped settings and cover placeholders
  invisible). Always build themes through it.
- Now Playing's gradient fades into `scheme.surface`, not pure black or white.

## Shape

| Element | Radius |
|---|---|
| Cover thumbnails (`CoverArtImage`, always use it; `externalUrl:` for Deezer art) | 8 |
| Grid album covers (`AlbumGridTile`, Library and artist pages) | 12 |
| Quality badges (FLAC, MP3) | 8 |
| Cards, banners, grouped-list sections | 16 |
| Bottom sheets (theme default; no hand-made `Material(borderRadius:)`) | 28 top |
| Floating dock | 16, selection pill 19 (a stadium on its 38 px height) |
| Mini player | paused: 28 pill with a round thumbnail; playing: 16 card with a 10 thumbnail |

## Type

Use the theme's text styles, never a raw `fontSize:`.

| Text | Style |
|---|---|
| Top-level tab titles (Home greeting, Library, Settings) | `AppTheme.pageTitleStyle` (`headlineMedium` bold) |
| Home feed sections | `titleLarge` bold |
| List sections on search, detail pages and the queue | `SectionHeader`: `titleMedium` bold + muted count |
| Settings group labels | `labelLarge` in `primary` |
| Detail-page header titles | `headlineSmall` bold |

## App bars

- Top-level tabs: a 64 px bar with the bold page title, no collapsing. Large or collapsing bars
  on top-level tabs were tried and dropped (they don't fit the app).
- Sub-pages (Settings pages, Downloads, Downloaded songs): `SliverAppBar.medium`.
- Album and playlist detail screens: a full-bleed cover-art `SliverAppBar` with
  `flexibleSpace`. Intentional; keep it.
- The artist page has its own portrait hero (see Artist page below).
- Home has no collapsing bar. M3's medium and large bars bottom-align the title, which left a
  ~100 px gap under the Android status bar (tried and reverted in v1.9.9). A second attempt must
  move the title inside the flexible space.

## Library

`lib/features/library/library_screen.dart`, views in `library_views.dart`.

- **Phone:** the 64 px title bar (Search, tonal + for New playlist), then single-select chips:
  All, Playlists, Albums, Artists, Songs. The chip used last is remembered (`libraryView`).
  Views are built on first visit and kept, so switching chips keeps scroll positions.
- **All (overview):** four pinned collections in a 2-column grid (4 at ≥ 700 px), each with an M3
  Expressive icon shape: Liked songs (cookie), Downloaded (pill), Recently added (rounded square),
  Shuffle all (circle). Then shelves under `titleLarge` bold headers with See all: Playlists
  (a dashed New playlist tile first, then most recently updated), Recently added albums, and
  Artists (most played locally). Everything comes from the cached library, so it works offline.
- **Lists:** a sort row (sort button left, count right, grid/list toggle for Albums and
  Playlists). Playlists you can't edit (Navidrome smart playlists, other users') carry a lock.
- **Search** filters the current chip; on All it searches playlists, artists, albums and songs.
- **Multi-select:** long-press a song; `SongSelectionAppBar` (secondary container) replaces the
  title bar with Add to playlist, Play next, Add to queue and an overflow (Download, Select all).
- **Wide (≥ 900 px):** a 288 px sidebar (Overview, Liked songs, Downloaded, Recently added,
  Albums, Artists, Songs, then every playlist) beside the content. Songs dragged from the content
  can be dropped on a playlist in the sidebar (`SongDragScope`).

## Playlists

- The playlist page and collection pages (Liked songs, Recently added) use `PlayButtonGroup`:
  a wide Play pill and square tonal buttons, like the artist page. Playlist: Shuffle, Add songs,
  Download; Edit and ⋮ (Rename, Duplicate, Delete) sit in the header's toolbar.
- Editing happens on its own screen (rename, description, remove with Undo, drag handles) and is
  sent on Done in as few requests as possible (`planSongChange`).
- "Add to playlist" is one sheet everywhere (song ⋮, album header, queue, selections): playlists
  already holding the song start ticked; New playlist sits at the top.

## Detail pages

Album and playlist pages share `DetailActions`: Play (filled) and Shuffle (tonal) at
48 px, plus a tonal download icon button where a bulk download exists. Album tracks show the
track number in the cover slot.

## Artist page

`lib/features/library/artist_detail_screen.dart`, sections in `lib/features/library/artist/`.

- **Tint:** the page re-seeds the theme (`AppTheme.seeded`, vibrant variant so the buttons keep the photo's hue) from the artist
  photo's palette, so every artist page has its own colours.
- **Hero:** the photo (server `getArtistInfo2` image, then Deezer, then the artist cover art) in
  the 9-lobe `CookieShape` over a blurred copy of itself; `displaySmall` w800 name, top two
  genres as chips, "N releases · N songs · runtime". The hero is sized to its content (the name
  may wrap); collapsed it becomes a bar with a small portrait, Shuffle and Play.
- **Actions:** a button group: a 64 px Play pill, then square tonal Shuffle, Artist radio and
  Download all (corner radius ≈ 31 % of the height).
- **Sections** sit in 28 px containers or under `titleLarge` bold titles, in this order: Your
  listening, Popular, Latest release, Discography, Not in your library, Fans also like, About,
  All songs. A section with no data is hidden; a failed request shows a compact `ErrorNotice`;
  online-only sections (Deezer, bio, similar) hide while the device is offline.
- **Discography:** filter chips by release type, a sort menu, and a `CarouselView.weighted`
  (5 : 3 : 1) that switches to a grid on request or for two releases or fewer.
- **All songs** is its own page (search, sort chips, multi-select), not an inline list.
- **Wide (≥ 900 px):** a 380 px identity pane (portrait, name, actions, listening) beside the
  content; Popular sits next to Latest release and the discography is always a grid.

## Motion

Home sections enter with a staggered fade and slide on the M3 emphasized-decelerate curve
(`Cubic(0.05, 0.7, 0.1, 1.0)`, 400 ms). Scroll physics follow the platform: bouncing on desktop,
clamping on Android.
