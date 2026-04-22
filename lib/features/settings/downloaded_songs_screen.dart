import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';

enum _DownloadedSongFilter { all, lossless, lossy }

enum _DownloadedSongSort { name, artist, album, recentlyAdded }

String _downloadedSongFilterLabel(_DownloadedSongFilter filter) =>
    switch (filter) {
      _DownloadedSongFilter.all => 'All',
      _DownloadedSongFilter.lossless => 'Lossless',
      _DownloadedSongFilter.lossy => 'Lossy',
    };

String _downloadedSongSortLabel(_DownloadedSongSort sort) => switch (sort) {
      _DownloadedSongSort.name => 'Name',
      _DownloadedSongSort.artist => 'Artist',
      _DownloadedSongSort.album => 'Album',
      _DownloadedSongSort.recentlyAdded => 'Recently added',
    };

IconData _downloadedSongSortIcon(_DownloadedSongSort sort) => switch (sort) {
      _DownloadedSongSort.name => Icons.sort_by_alpha_rounded,
      _DownloadedSongSort.artist => Icons.person_rounded,
      _DownloadedSongSort.album => Icons.album_rounded,
      _DownloadedSongSort.recentlyAdded => Icons.schedule_rounded,
    };

bool _isLossless(Song song) {
  final suffix = song.suffix?.toLowerCase();
  return switch (suffix) {
    'flac' || 'alac' || 'wav' || 'aiff' || 'ape' || 'dsf' || 'dff' => true,
    _ => false,
  };
}

bool _matchesSongFilter(Song song, _DownloadedSongFilter filter) {
  return switch (filter) {
    _DownloadedSongFilter.all => true,
    _DownloadedSongFilter.lossless => _isLossless(song),
    _DownloadedSongFilter.lossy => !_isLossless(song),
  };
}

bool _matchesSongQuery(Song song, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return song.title.toLowerCase().contains(needle) ||
      song.artist.toLowerCase().contains(needle) ||
      song.album.toLowerCase().contains(needle) ||
      (song.genre?.toLowerCase().contains(needle) ?? false) ||
      (song.suffix?.toLowerCase().contains(needle) ?? false);
}

List<Song> _sortDownloadedSongs(
  Iterable<Song> songs,
  _DownloadedSongSort sort,
  bool ascending,
) {
  final list = songs.toList();
  switch (sort) {
    case _DownloadedSongSort.name:
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case _DownloadedSongSort.artist:
      list.sort((a, b) {
        final artistCompare =
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        if (artistCompare != 0) return artistCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    case _DownloadedSongSort.album:
      list.sort((a, b) {
        final albumCompare =
            a.album.toLowerCase().compareTo(b.album.toLowerCase());
        if (albumCompare != 0) return albumCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    case _DownloadedSongSort.recentlyAdded:
      list.sort((a, b) {
        if (a.created == null && b.created == null) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        if (a.created == null) return 1;
        if (b.created == null) return -1;
        final dateCompare = b.created!.compareTo(a.created!);
        if (dateCompare != 0) return dateCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }
  return ascending ? list : list.reversed.toList();
}

class _SortSelection {
  final _DownloadedSongSort sort;
  final bool ascending;

  const _SortSelection({
    required this.sort,
    required this.ascending,
  });
}

class DownloadedSongsScreen extends ConsumerStatefulWidget {
  const DownloadedSongsScreen({super.key});

  @override
  ConsumerState<DownloadedSongsScreen> createState() =>
      _DownloadedSongsScreenState();
}

class _DownloadedSongsScreenState extends ConsumerState<DownloadedSongsScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  _DownloadedSongFilter _filter = _DownloadedSongFilter.all;
  _DownloadedSongSort _sort = _DownloadedSongSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _filter != _DownloadedSongFilter.all ||
      _sort != _DownloadedSongSort.name ||
      !_ascending;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = _DownloadedSongFilter.all;
      _sort = _DownloadedSongSort.name;
      _ascending = true;
    });
  }

  Future<void> _showSortSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_SortSelection>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        var sheetSort = _sort;
        var sheetAscending = _ascending;
        final scheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Sort downloaded songs',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip:
                                sheetAscending ? 'Ascending' : 'Descending',
                            onPressed: () {
                              setSheetState(() {
                                sheetAscending = !sheetAscending;
                              });
                            },
                            icon: Icon(
                              sheetAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final option in _DownloadedSongSort.values)
                      ListTile(
                        leading: Icon(
                          _downloadedSongSortIcon(option),
                          color: option == sheetSort ? scheme.primary : null,
                        ),
                        title: Text(_downloadedSongSortLabel(option)),
                        trailing: option == sheetSort
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          _SortSelection(
                            sort: option,
                            ascending: sheetAscending,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _sort = result.sort;
      _ascending = result.ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(downloadedSongsProvider);
    final scheme = Theme.of(context).colorScheme;

    // Keep the structure stable while active downloads update. Individual
    // tiles still watch their own progress to avoid repainting the whole list.
    final activeIdsString = ref.watch(downloadNotifierProvider.select((m) {
      final ids = m.entries
          .where((e) =>
              e.value.status == 'downloading' || e.value.status == 'queued')
          .map((e) => e.key)
          .toList()
        ..sort();
      return ids.join(',');
    }));
    final activeIds =
        activeIdsString.isEmpty ? const <String>[] : activeIdsString.split(',');
    final activeDownloads = ref.read(downloadNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Songs'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (songs) {
          final hasAnyContent = songs.isNotEmpty || activeIds.isNotEmpty;
          if (!hasAnyContent) {
            return _EmptyDownloadsState(
              scheme: scheme,
            );
          }

          final filteredSongs = _sortDownloadedSongs(
            songs.where((song) {
              return _matchesSongQuery(song, _query) &&
                  _matchesSongFilter(song, _filter);
            }),
            _sort,
            _ascending,
          );

          final filteredActiveIds = activeIds.where((id) {
            final item = activeDownloads[id];
            if (item == null) return false;
            return _matchesSongQuery(item.song, _query) &&
                _matchesSongFilter(item.song, _filter);
          }).toList();

          final hasMatches =
              filteredSongs.isNotEmpty || filteredActiveIds.isNotEmpty;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _FilterPanel(
                    query: _query,
                    controller: _searchController,
                    selectedFilter: _filter,
                    sort: _sort,
                    ascending: _ascending,
                    hasActiveFilters: _hasActiveFilters,
                    onQueryChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    onClearQuery: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                    onFilterSelected: (filter) {
                      setState(() {
                        _filter = filter;
                      });
                    },
                    onSortPressed: () => _showSortSheet(context),
                    onClearPressed: _clearFilters,
                  ),
                ),
              ),
              if (!hasMatches)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoMatchesState(
                    scheme: scheme,
                    onClear: _clearFilters,
                  ),
                )
              else ...[
                if (filteredActiveIds.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.downloading_rounded,
                      title: 'Downloading now',
                      subtitle:
                          '${filteredActiveIds.length} active download${filteredActiveIds.length == 1 ? '' : 's'}',
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) =>
                          _ActiveDownloadTile(songId: filteredActiveIds[i]),
                      childCount: filteredActiveIds.length,
                    ),
                  ),
                ],
                if (filteredSongs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.download_done_rounded,
                      title: 'Saved on this device',
                      subtitle: _hasActiveFilters
                          ? '${filteredSongs.length} of ${songs.length} songs'
                          : '${songs.length} song${songs.length == 1 ? '' : 's'}',
                      trailing: TextButton.icon(
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete all'),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: () => _confirmDeleteAll(context, ref, songs),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => SongTile(
                        song: filteredSongs[i],
                        showAlbum: true,
                        onTap: () => ref
                            .read(audioHandlerNotifierProvider)
                            ?.loadQueue(filteredSongs, startIndex: i),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_done_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _deleteSong(context, ref, filteredSongs[i]),
                            ),
                          ],
                        ),
                      ),
                      childCount: filteredSongs.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteSong(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text('Remove "${song.title}" from device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _removeDownload(ref, song);
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all downloads?'),
        content:
            Text('Remove all ${songs.length} downloaded songs from device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final song in songs) {
      await _removeDownload(ref, song);
    }
  }

  Future<void> _removeDownload(WidgetRef ref, Song song) async {
    await ref.read(downloadNotifierProvider.notifier).removeDownload(song.id);
  }
}

class _FilterPanel extends StatelessWidget {
  final String query;
  final TextEditingController controller;
  final _DownloadedSongFilter selectedFilter;
  final _DownloadedSongSort sort;
  final bool ascending;
  final bool hasActiveFilters;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<_DownloadedSongFilter> onFilterSelected;
  final VoidCallback onSortPressed;
  final VoidCallback onClearPressed;

  const _FilterPanel({
    required this.query,
    required this.controller,
    required this.selectedFilter,
    required this.sort,
    required this.ascending,
    required this.hasActiveFilters,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onFilterSelected,
    required this.onSortPressed,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBar(
          controller: controller,
          hintText: 'Search title, artist, album',
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear search',
                onPressed: onClearQuery,
              ),
          ],
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final option in _DownloadedSongFilter.values)
              ChoiceChip(
                label: Text(_downloadedSongFilterLabel(option)),
                selected: option == selectedFilter,
                onSelected: (_) => onFilterSelected(option),
              ),
            ActionChip(
              avatar: Icon(_downloadedSongSortIcon(sort), size: 18),
              label: Text(
                '${_downloadedSongSortLabel(sort)} ${ascending ? '↑' : '↓'}',
              ),
              onPressed: onSortPressed,
            ),
            if (hasActiveFilters)
              ActionChip(
                avatar: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
                onPressed: onClearPressed,
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyDownloadsState extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyDownloadsState({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No downloaded songs',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the download icon on any song to save it offline.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  final ColorScheme scheme;
  final VoidCallback onClear;

  const _NoMatchesState({
    required this.scheme,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'No matches',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search or clear the current filters.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// Each tile only rebuilds when its own download's progress/status changes,
// not when other songs' downloads update.
class _ActiveDownloadTile extends ConsumerWidget {
  final String songId;
  const _ActiveDownloadTile({required this.songId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      downloadNotifierProvider.select((m) => m[songId]),
    );
    if (item == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CoverArtImage(coverArtId: item.song.coverArt, size: 48),
      title: Text(
        item.song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (item.status != 'queued')
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
        ],
      ),
      trailing: Text(
        item.status == 'queued'
            ? 'Queued'
            : '${(item.progress * 100).round()}%',
        style: TextStyle(
          fontSize: 12,
          color: item.status == 'queued'
              ? scheme.onSurfaceVariant
              : scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
