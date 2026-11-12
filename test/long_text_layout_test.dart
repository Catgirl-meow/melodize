// Layout checks for long names: the collapsing page header and the
// scrolling Now Playing title. Any overflow fails a widget test by itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/shared/widgets/detail_header.dart';
import 'package:melodize/shared/widgets/marquee_text.dart';

const _longName =
    'A Collection of Songs Whose Titles Are Far Too Long for Any Reasonable '
    'Screen (Deluxe 25th Anniversary Edition)';

Widget _app(Widget child) => ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 780)),
          child: child,
        ),
      ),
    );

void main() {
  testWidgets('detail header wraps when expanded, one line when collapsed',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(Scaffold(
      body: CustomScrollView(slivers: [
        const DetailHeader(
          title: _longName,
          subtitle: 'An artist whose name is also rather long · 2024',
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => SizedBox(height: 60, child: Text('row $i')),
            childCount: 40,
          ),
        ),
      ]),
    )));

    // Expanded: the big title is shown and wraps past one line.
    final big = find.text(_longName);
    expect(big, findsOneWidget);
    expect(tester.getSize(big).height, greaterThan(40));

    // Collapsed: only the toolbar title is left, one line inside the bar.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(big, findsOneWidget);
    final rect = tester.getRect(big);
    expect(rect.height, lessThan(40));
    expect(rect.bottom, lessThanOrEqualTo(kToolbarHeight + 1));
    expect(rect.left, greaterThanOrEqualTo(56));
  });

  testWidgets('marquee scrolls long text and leaves short text alone',
      (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: SizedBox(
        width: 200,
        child: Column(children: [
          MarqueeText('Short'),
          MarqueeText(_longName),
        ]),
      ),
    )));
    await tester.pump();
    // Short text is one plain Text; long text is drawn twice (loop copy).
    expect(find.text('Short'), findsOneWidget);
    expect(find.text(_longName), findsNWidgets(2));
    final before = tester.getTopLeft(find.text(_longName).first).dx;
    await tester.pump(const Duration(seconds: 4));
    final after = tester.getTopLeft(find.text(_longName).first).dx;
    expect(after, lessThan(before));
    // Stop the repeating animation before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
