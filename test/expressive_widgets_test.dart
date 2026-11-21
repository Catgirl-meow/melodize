import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/shared/widgets/morph_button.dart';
import 'package:melodize/shared/widgets/wavy_slider.dart';
import 'package:melodize/widgets/grouped_list_tile.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    );

void main() {
  group('WavySlider', () {
    testWidgets('dragging reports start, changes and end in order',
        (tester) async {
      final events = <String>[];
      double value = 0.2;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => _host(WavySlider(
          value: value,
          playing: true,
          color: Colors.purple,
          trackColor: Colors.grey,
          onChangeStart: (v) => events.add('start'),
          onChanged: (v) {
            events.add('change');
            setState(() => value = v);
          },
          onChangeEnd: (v) => events.add('end ${v.toStringAsFixed(1)}'),
        )),
      ));
      final box = tester.getRect(find.byType(WavySlider));
      final g = await tester.startGesture(box.centerLeft + const Offset(30, 0));
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(300, 0));
      await g.up();
      await tester.pump();
      expect(events.first, 'start');
      expect(events.where((e) => e == 'change'), isNotEmpty);
      // Dragged past the right end: clamps to 1.
      expect(events.last, 'end 1.0');
    });

    testWidgets('a tap seeks once', (tester) async {
      double? ended;
      await tester.pumpWidget(_host(WavySlider(
        value: 0,
        playing: false,
        color: Colors.purple,
        trackColor: Colors.grey,
        onChanged: (_) {},
        onChangeEnd: (v) => ended = v,
      )));
      await tester.tap(find.byType(WavySlider));
      await tester.pump();
      expect(ended, closeTo(0.5, 0.05));
    });

    testWidgets('keeps ticking only while playing', (tester) async {
      Widget slider(bool playing) => _host(WavySlider(
            value: 0.5,
            playing: playing,
            color: Colors.purple,
            trackColor: Colors.grey,
          ));
      await tester.pumpWidget(slider(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Paused: the wave flattens, then the ticker stops.
      await tester.pumpWidget(slider(false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stays still under reduce motion', (tester) async {
      await tester.pumpWidget(_host(
        const WavySlider(
          value: 0.5,
          playing: true,
          color: Colors.purple,
          trackColor: Colors.grey,
        ),
        reduceMotion: true,
      ));
      // pumpAndSettle would time out if the wave kept animating.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('MorphButton', () {
    testWidgets('fires onPressed and settles after a shape change',
        (tester) async {
      var taps = 0;
      Widget button(bool playing) => _host(Center(
              child: MorphButton(
            width: playing ? 84 : 72,
            height: 72,
            radius: playing ? 22 : 36,
            color: Colors.purple,
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: () => taps++,
            child: const Icon(Icons.play_arrow_rounded),
          )));
      await tester.pumpWidget(button(false));
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.pumpWidget(button(true));
      await tester.pumpAndSettle();
      final material = find.descendant(
          of: find.byType(MorphButton), matching: find.byType(Material));
      expect(tester.getSize(material).width, closeTo(84, 0.5));
    });
  });

  group('GroupedListTile', () {
    BorderRadius radiusOf(WidgetTester tester) {
      final m = tester.widget<Material>(find
          .descendant(
              of: find.byType(GroupedListTile), matching: find.byType(Material))
          .first);
      return m.borderRadius! as BorderRadius;
    }

    testWidgets('a held tappable tile rounds its corners, then springs back',
        (tester) async {
      await tester.pumpWidget(_host(GroupedListTile(
        borderRadius: BorderRadius.circular(4),
        child: ListTile(title: const Text('Theme'), onTap: () {}),
      )));
      final g = await tester.startGesture(tester.getCenter(find.text('Theme')));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(radiusOf(tester).topLeft.x, 20);
      await g.up();
      await tester.pumpAndSettle();
      expect(radiusOf(tester).topLeft.x, 4);
    });

    testWidgets('a read-only row never looks pressed', (tester) async {
      await tester.pumpWidget(_host(GroupedListTile(
        borderRadius: BorderRadius.circular(4),
        child: const ListTile(title: Text('Server URL')),
      )));
      final g =
          await tester.startGesture(tester.getCenter(find.text('Server URL')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(radiusOf(tester).topLeft.x, 4);
      await g.up();
    });
  });
}
