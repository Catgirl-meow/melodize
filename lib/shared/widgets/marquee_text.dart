import 'package:flutter/material.dart';

/// One line of text that scrolls sideways when it does not fit, instead of
/// being cut off with an ellipsis. Text that fits is drawn as a plain [Text].
///
/// It pauses at the start of each loop so the beginning stays readable, and
/// falls back to an ellipsis when the platform asks for reduced motion.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Scroll speed in logical pixels per second.
  final double velocity;
  final Duration pause;
  final double gap;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 32,
    this.pause = const Duration(seconds: 2),
    this.gap = 48,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  double _scrollExtent = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(double scrollExtent) {
    if (scrollExtent == _scrollExtent && _controller.isAnimating) return;
    _scrollExtent = scrollExtent;
    final scrollMs = (scrollExtent / widget.velocity * 1000).round();
    final total = widget.pause.inMilliseconds + scrollMs;
    _controller
      ..stop()
      ..duration = Duration(milliseconds: total)
      ..repeat();
  }

  void _halt() {
    if (_controller.isAnimating) _controller.stop();
    _controller.value = 0;
    _scrollExtent = 0;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final textWidth = painter.width;
      final height = painter.height;
      painter.dispose();

      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (textWidth <= constraints.maxWidth || reduceMotion) {
        if (_controller.isAnimating || _controller.value != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _halt();
          });
        }
        return Text(widget.text,
            style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
      }

      final extent = textWidth + widget.gap;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(extent);
      });
      final pauseFraction = widget.pause.inMilliseconds /
          (widget.pause.inMilliseconds + extent / widget.velocity * 1000);

      final line = Text(widget.text,
          style: widget.style, maxLines: 1, softWrap: false);
      return SizedBox(
        width: constraints.maxWidth,
        height: height,
        child: ShaderMask(
          // Soft edges so the text does not look chopped where it scrolls.
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.04, 0.92, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                final v = _controller.value;
                final p = v <= pauseFraction
                    ? 0.0
                    : (v - pauseFraction) / (1 - pauseFraction);
                return Transform.translate(
                  offset: Offset(-extent * p, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [line, SizedBox(width: widget.gap), line],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
