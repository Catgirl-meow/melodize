import '../../core/library/artist_profile.dart' show formatRuntime;
import '../../core/models/song.dart';

/// "1 song", "12 songs".
String songCount(int n) => n == 1 ? '1 song' : '$n songs';

/// Total length of [songs], e.g. "2 h 4 min".
String totalRuntime(Iterable<Song> songs) => formatRuntime(
    Duration(seconds: songs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0))));

/// "updated today", "updated yesterday", "updated 3 days ago",
/// "updated 12 Mar 2026". Null for an unknown date.
String? updatedLabel(DateTime? when, {DateTime? now}) {
  if (when == null) return null;
  final local = when.toLocal();
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return 'updated today';
  if (days == 1) return 'updated yesterday';
  if (days < 7) return 'updated $days days ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return 'updated ${local.day} ${months[local.month - 1]} ${local.year}';
}
