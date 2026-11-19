// Shared driver for the integration tests. Every test runs the real app
// against the throwaway Navidrome (scripts/test-navidrome.sh) and gets the
// server from dart-defines; scripts/test-linux.sh and scripts/test-android.sh
// pass them. See docs/testing.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melodize/core/audio/audio_handler.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/features/player/mini_player.dart';
import 'package:melodize/features/search/search_screen.dart';
import 'package:melodize/features/setup/setup_screen.dart';
import 'package:melodize/features/shell/main_shell.dart';
import 'package:melodize/shared/widgets/song_tile.dart';

const ndUrl = String.fromEnvironment('ND_URL');
const ndUser = String.fromEnvironment('ND_USER');
const ndPass = String.fromEnvironment('ND_PASS');

/// Call first in every integration test's main().
void initIntegration() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // A tap that lands on another widget (the mini player covering a list
  // row, say) fails right there instead of timing out later.
  WidgetController.hitTestWarningShouldBeFatal = true;
}

void requireServer() {
  expect(ndUrl, isNotEmpty,
      reason: 'pass --dart-define=ND_URL=... (scripts/test-linux.sh or '
          'scripts/test-android.sh do it for you)');
}

// pumpAndSettle never settles while a progress indicator spins or a song
// plays, so pump until the finder matches or the timeout passes.
Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder\n${visibleTexts()}');
}

/// The texts on screen right now, to show what a failed wait saw instead.
String visibleTexts() {
  final texts = find
      .byType(Text)
      .hitTestable()
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText())
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .take(40)
      .toList();
  return 'On screen: ${texts.join(' | ')}';
}

/// Pumps until [condition] holds (for state that has no widget to find).
Future<void> pumpUntilTrue(WidgetTester tester, bool Function() condition,
    {String? reason, Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for ${reason ?? 'condition'}');
}

/// Pumps frames for [d] without waiting for the app to settle.
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] to the middle of its scrollable (clear of the mini
/// player and nav bar on a phone), then taps it. A widget that is not built
/// yet (far down a lazy list or grid) is scrolled into existence first. A
/// tap that would land on another widget fails the test instead of silently
/// doing nothing.
Future<void> tapVisible(WidgetTester tester, Finder finder,
    {Duration settle = const Duration(milliseconds: 500)}) async {
  await scrollIntoView(tester, finder);
  final target = finder.first;
  if (Scrollable.maybeOf(tester.element(target)) != null) {
    await Scrollable.ensureVisible(tester.element(target),
        alignment: 0.4, duration: Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(target);
  await pumpFor(tester, settle);
}

/// Waits for [finder]; if it does not show up, scrolls the main vertical
/// list on screen down step by step until it is built.
Future<void> scrollIntoView(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  var waited = 0;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    // Give loading a moment before scrolling.
    if (++waited < 10) continue;
    final list = _mainVerticalScrollable();
    if (list == null) continue;
    final pos = list.position;
    if (pos.pixels >= pos.maxScrollExtent) continue;
    pos.jumpTo((pos.pixels + pos.viewportDimension * 0.6)
        .clamp(0, pos.maxScrollExtent));
  }
  throw TestFailure('Timed out waiting for $finder\n${visibleTexts()}');
}

ScrollableState? _mainVerticalScrollable() {
  ScrollableState? best;
  var bestArea = 0.0;
  for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final area = box.size.width * box.size.height;
    if (area > bestArea) {
      bestArea = area;
      best = state;
    }
  }
  return best;
}

Future<void> fillSetup(
    WidgetTester tester, String url, String user, String pass) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), url);
  await tester.enterText(fields.at(1), user);
  await tester.enterText(fields.at(2), pass);
  await tester.tap(find.text('Connect'));
  await tester.pump();
}

/// Waits for the first screen and connects to the test server when the app
/// starts on the setup screen.
Future<void> connectIfNeeded(WidgetTester tester) async {
  await pumpUntil(tester,
      find.byWidgetPredicate((w) => w is SetupScreen || w is MainShell));
  if (find.byType(SetupScreen).evaluate().isNotEmpty) {
    await fillSetup(tester, ndUrl, ndUser, ndPass);
  }
  await pumpUntil(tester, find.byType(MainShell));
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label).last);
  await pumpFor(tester, const Duration(milliseconds: 600));
}

/// Pops the topmost route: detail pages and sheets live on the root
/// navigator, above the shell's per-tab navigators.
Future<void> goBack(WidgetTester tester) async {
  final navs = find
      .byType(Navigator)
      .evaluate()
      .map((e) => (e as StatefulElement).state as NavigatorState)
      .toList();
  final root = navs.first;
  await (root.canPop()
          ? root
          : navs.lastWhere((n) => n.canPop(), orElse: () => root))
      .maybePop();
  await pumpFor(tester, const Duration(milliseconds: 600));
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MainShell)));

MelodizeAudioHandler handlerOf(WidgetTester tester) =>
    container(tester).read(audioHandlerNotifierProvider)!;

/// The song row (a [SongTile]) titled exactly [title].
Finder songRow(String title) => find.ancestor(
    of: find.text(title), matching: find.byType(SongTile));

Song songTile(WidgetTester tester, String title) =>
    tester.widget<SongTile>(songRow(title).first).song;

/// Search tab: types [query] and waits for a song row titled [title].
Future<void> searchSong(WidgetTester tester, String query, String title) async {
  await openTab(tester, 'Search');
  // Other tabs stay alive offstage, so pick the search screen's own field.
  final field = find.descendant(
      of: find.byType(SearchScreen), matching: find.byType(TextField));
  await pumpUntil(tester, field);
  // Clear a previous query first: typing into a field that still holds one
  // after a sheet closed did not reach the search on Android.
  final clear = find.byTooltip('Clear search').hitTestable();
  if (clear.evaluate().isNotEmpty) {
    await tester.tap(clear.first);
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.enterText(field.first, query);
  await pumpUntil(tester, songRow(title));
}

/// Opens the options sheet of the song row titled [title].
Future<void> openSongOptions(WidgetTester tester, String title) async {
  await pumpUntil(tester, songRow(title));
  await tapVisible(
      tester,
      find.descendant(
          of: songRow(title).first,
          matching: find.byIcon(Icons.more_vert_rounded)));
  await pumpUntil(tester, find.text('Add to queue'));
}

Future<void> openNowPlaying(WidgetTester tester) async {
  await tester.tap(find
      .descendant(of: find.byType(MiniPlayer), matching: find.byType(Text))
      .first);
  await pumpUntil(tester, find.text('Now Playing'));
  await pumpFor(tester, const Duration(milliseconds: 500));
}

/// Pauses if something is playing, so the rest of a run stays quiet.
Future<void> pauseIfPlaying(WidgetTester tester) async {
  final h = handlerOf(tester);
  if (h.player.playing) await h.pause();
  await tester.pump();
}
